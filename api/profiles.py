"""
档案管理API路由
"""
import time
from typing import List, Optional, Dict, Tuple, Any

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import uuid
from datetime import datetime
import logging
import traceback

from database.connection import get_db
from database.models import Profile, Session, AnalysisResult
from auth.jwt_handler import get_current_user_id
from pydantic import BaseModel

logger = logging.getLogger(__name__)

# 档案列表短期缓存，TTL 60 秒；创建/更新/删除时按 user_id 失效
_PROFILES_CACHE_TTL = 60
_profiles_cache: Dict[str, Tuple[List[dict], float]] = {}


def _invalidate_profiles_cache(user_id: str):
    if user_id in _profiles_cache:
        del _profiles_cache[user_id]
        logger.debug("档案列表缓存已失效: %s", user_id)


router = APIRouter(prefix="/api/v1/profiles", tags=["profiles"])


# Pydantic模型
class ProfileCreate(BaseModel):
    name: str
    relationship: str
    photo_url: Optional[str] = None
    notes: Optional[str] = None
    audio_session_id: Optional[str] = None
    audio_segment_id: Optional[str] = None
    audio_start_time: Optional[float] = None
    audio_end_time: Optional[float] = None
    audio_url: Optional[str] = None


class ProfileUpdate(BaseModel):
    name: Optional[str] = None
    relationship: Optional[str] = None
    photo_url: Optional[str] = None
    notes: Optional[str] = None
    audio_session_id: Optional[str] = None
    audio_segment_id: Optional[str] = None
    audio_start_time: Optional[float] = None
    audio_end_time: Optional[float] = None
    audio_url: Optional[str] = None


class ProfileResponse(BaseModel):
    id: str
    name: str
    relationship: str
    photo_url: Optional[str] = None
    notes: Optional[str] = None
    audio_session_id: Optional[str] = None
    audio_segment_id: Optional[str] = None
    audio_start_time: Optional[float] = None
    audio_end_time: Optional[float] = None
    audio_url: Optional[str] = None
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True


def _profile_to_response(p: Profile) -> ProfileResponse:
    return ProfileResponse(
        id=str(p.id),
        name=p.name,
        relationship=p.relationship_type,
        photo_url=p.photo_url,
        notes=p.notes,
        audio_session_id=str(p.audio_session_id) if p.audio_session_id else None,
        audio_segment_id=p.audio_segment_id,
        audio_start_time=float(p.audio_start_time) if p.audio_start_time else None,
        audio_end_time=float(p.audio_end_time) if p.audio_end_time else None,
        audio_url=p.audio_url,
        created_at=p.created_at.isoformat(),
        updated_at=p.updated_at.isoformat(),
    )


@router.get("", response_model=List[ProfileResponse])
async def get_profiles(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取当前用户的所有档案"""
    try:
        now = time.time()
        if user_id in _profiles_cache:
            cached, expiry = _profiles_cache[user_id]
            if now < expiry:
                return [ProfileResponse(**d) for d in cached]

        result = await db.execute(
            select(Profile).where(Profile.user_id == uuid.UUID(user_id))
        )
        profiles = result.scalars().all()
        out = [_profile_to_response(p) for p in profiles]
        _profiles_cache[user_id] = ([r.model_dump() for r in out], now + _PROFILES_CACHE_TTL)
        return out
    except Exception as e:
        logger.error(f"获取档案列表失败: {type(e).__name__}: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取档案列表失败: {str(e)}")


@router.post("", response_model=ProfileResponse, status_code=201)
async def create_profile(
    profile_data: ProfileCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """创建新档案"""
    audio_session_id = None
    if profile_data.audio_session_id and str(profile_data.audio_session_id).strip():
        try:
            audio_session_id = uuid.UUID(profile_data.audio_session_id)
        except (ValueError, TypeError):
            pass
    profile = Profile(
        id=uuid.uuid4(),
        user_id=uuid.UUID(user_id),
        name=profile_data.name,
        relationship_type=profile_data.relationship,
        photo_url=profile_data.photo_url,
        notes=profile_data.notes,
        audio_session_id=audio_session_id,
        audio_segment_id=profile_data.audio_segment_id,
        audio_start_time=int(profile_data.audio_start_time) if profile_data.audio_start_time else None,
        audio_end_time=int(profile_data.audio_end_time) if profile_data.audio_end_time else None,
        audio_url=profile_data.audio_url
    )
    
    db.add(profile)
    await db.commit()
    _invalidate_profiles_cache(user_id)
    # 移除不必要的refresh，created_at和updated_at由数据库自动生成，但对象中已有值
    # await db.refresh(profile)  # 已移除，减少一次数据库查询

    return ProfileResponse(
        id=str(profile.id),
        name=profile.name,
        relationship=profile.relationship_type,
        photo_url=profile.photo_url,
        notes=profile.notes,
        audio_session_id=str(profile.audio_session_id) if profile.audio_session_id else None,
        audio_segment_id=profile.audio_segment_id,
        audio_start_time=float(profile.audio_start_time) if profile.audio_start_time else None,
        audio_end_time=float(profile.audio_end_time) if profile.audio_end_time else None,
        audio_url=profile.audio_url,
        created_at=profile.created_at.isoformat(),
        updated_at=profile.updated_at.isoformat()
    )


@router.put("/{profile_id}", response_model=ProfileResponse)
async def update_profile(
    profile_id: str,
    profile_data: ProfileUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """更新档案"""
    result = await db.execute(
        select(Profile).where(
            Profile.id == uuid.UUID(profile_id),
            Profile.user_id == uuid.UUID(user_id)
        )
    )
    profile = result.scalar_one_or_none()
    
    if not profile:
        raise HTTPException(status_code=404, detail="档案不存在")
    
    # 更新字段
    if profile_data.name is not None:
        profile.name = profile_data.name
    if profile_data.relationship is not None:
        profile.relationship_type = profile_data.relationship
    if profile_data.photo_url is not None:
        profile.photo_url = profile_data.photo_url
    if profile_data.notes is not None:
        profile.notes = profile_data.notes
    if profile_data.audio_session_id is not None:
        profile.audio_session_id = uuid.UUID(profile_data.audio_session_id) if profile_data.audio_session_id else None
    if profile_data.audio_segment_id is not None:
        profile.audio_segment_id = profile_data.audio_segment_id
    if profile_data.audio_start_time is not None:
        profile.audio_start_time = int(profile_data.audio_start_time)
    if profile_data.audio_end_time is not None:
        profile.audio_end_time = int(profile_data.audio_end_time)
    if profile_data.audio_url is not None:
        profile.audio_url = profile_data.audio_url
    
    # 提交更改
    await db.commit()
    _invalidate_profiles_cache(user_id)
    # 刷新对象以获取最新的updated_at（由数据库自动更新）
    await db.refresh(profile)

    return ProfileResponse(
        id=str(profile.id),
        name=profile.name,
        relationship=profile.relationship_type,
        photo_url=profile.photo_url,
        notes=profile.notes,
        audio_session_id=str(profile.audio_session_id) if profile.audio_session_id else None,
        audio_segment_id=profile.audio_segment_id,
        audio_start_time=float(profile.audio_start_time) if profile.audio_start_time else None,
        audio_end_time=float(profile.audio_end_time) if profile.audio_end_time else None,
        audio_url=profile.audio_url,
        created_at=profile.created_at.isoformat(),
        updated_at=profile.updated_at.isoformat()
    )


@router.delete("/{profile_id}", status_code=204)
async def delete_profile(
    profile_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """删除档案"""
    result = await db.execute(
        select(Profile).where(
            Profile.id == uuid.UUID(profile_id),
            Profile.user_id == uuid.UUID(user_id)
        )
    )
    profile = result.scalar_one_or_none()
    
    if not profile:
        raise HTTPException(status_code=404, detail="档案不存在")
    
    await db.delete(profile)
    await db.commit()
    _invalidate_profiles_cache(user_id)
    return None


@router.post("/upload-photo", summary="上传档案照片")
async def upload_profile_photo(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """上传档案照片到OSS并返回URL"""
    try:
        # 读取文件内容
        file_content = await file.read()
        file_size = len(file_content)
        
        logger.info(f"收到图片上传请求: 文件名={file.filename}, 大小={file_size} 字节, 用户={user_id}")
        
        # 导入OSS上传函数
        from main import upload_image_to_oss
        
        # 生成唯一的图片ID
        image_id = str(uuid.uuid4())
        
        # 上传到OSS (使用 user_id 和 image_id 作为路径)
        logger.info(f"开始上传图片到OSS: image_id={image_id}, user_id={user_id}")
        photo_url = upload_image_to_oss(
            image_bytes=file_content,
            user_id=user_id,
            session_id=f"profile_{image_id}",  # 使用 profile_ 前缀区分
            image_index=0
        )
        
        if not photo_url:
            logger.error(f"❌ OSS上传返回None，可能OSS未启用或上传失败")
            raise HTTPException(status_code=500, detail="图片上传失败：OSS上传返回空结果")
        
        logger.info(f"✅ 图片上传成功: {photo_url}")
        
        response_data = {
            "photo_url": photo_url
        }
        logger.info(f"返回响应数据: {response_data}")
        return response_data
    except HTTPException:
        # 重新抛出HTTP异常
        raise
    except Exception as e:
        logger.error(f"上传图片失败: {e}")
        logger.error(f"错误类型: {type(e).__name__}")
        logger.error(f"错误详情: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=f"上传图片失败: {str(e)}")
