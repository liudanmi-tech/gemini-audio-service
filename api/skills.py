"""
技能管理API接口
包括获取技能列表、技能详情、重新加载技能等
"""
import os, time
from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from pydantic import BaseModel
from typing import List, Optional, Dict, Tuple, Any

import logging

from database.connection import get_db
from auth.jwt_handler import get_current_user_id
from skills.registry import list_skills, get_skill, reload_skill, register_skill
from skills.loader import create_skill_file, update_skill_file
from database.models import UserSkillPreference

logger = logging.getLogger(__name__)

# 技能列表应用内缓存，TTL 5 分钟；创建/更新/重载时失效
_SKILLS_LIST_CACHE_TTL = 300
_skills_list_cache: Dict[Tuple[Optional[str], bool], Tuple[List[Dict], float]] = {}


def _invalidate_skills_list_cache():
    """创建/更新/重载技能后调用，清空列表缓存"""
    _skills_list_cache.clear()
    logger.debug("技能列表缓存已失效")


router = APIRouter(prefix="/api/v1/skills", tags=["技能管理"])


class SkillResponse(BaseModel):
    """技能响应模型"""
    skill_id: str
    name: str
    description: Optional[str] = None
    category: str
    priority: int
    enabled: bool
    version: Optional[str] = None
    metadata: Optional[dict] = None


class SkillListResponse(BaseModel):
    """技能列表响应"""
    skills: List[SkillResponse]


class SkillDetailResponse(BaseModel):
    """技能详情响应"""
    skill_id: str
    name: str
    description: Optional[str] = None
    category: str
    skill_path: str
    priority: int
    enabled: bool
    version: Optional[str] = None
    metadata: Optional[dict] = None
    # 注意：prompt_template 不包含在响应中，需要单独接口获取


class SkillCreate(BaseModel):
    """创建技能请求"""
    skill_id: str
    name: str
    description: Optional[str] = ""
    category: str = "other"
    priority: int = 0
    enabled: bool = True
    version: str = "1.0.0"


class SkillUpdate(BaseModel):
    """更新技能请求（全部可选）"""
    name: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    priority: Optional[int] = None
    enabled: Optional[bool] = None
    version: Optional[str] = None


class SkillPreferencesUpdate(BaseModel):
    """更新技能偏好请求"""
    selected_skills: List[str]
    is_manual_mode: Optional[bool] = None  # None 表示不改变当前模式


_CATALOG_CATEGORY_ORDER = ["workplace", "family", "personal"]
_CATALOG_CATEGORY_NAMES = {
    "workplace": "职场",
    "family": "家庭",
    "personal": "个人成长",
}
_CATALOG_CATEGORY_ICONS = {
    "workplace": "briefcase.fill",
    "family": "house.fill",
    "personal": "person.fill",
}


@router.get("", summary="获取所有可用技能")
async def get_all_skills(
    category: Optional[str] = None,
    enabled: Optional[bool] = Query(default=True, description="是否只返回启用的技能"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    获取所有可用技能
    
    - **category**: 可选，按分类筛选（workplace/family/education/brainstorm）
    - **enabled**: 是否只返回启用的技能（默认 true）
    """
    try:
        enabled_bool = bool(enabled) if enabled is not None else True
        cache_key = (category, enabled_bool)
        now = time.time()
        if cache_key in _skills_list_cache:
            skills, expiry = _skills_list_cache[cache_key]
            if now < expiry:
                skill_responses = [
                    SkillResponse(
                        skill_id=s["skill_id"],
                        name=s["name"],
                        description=s.get("description"),
                        category=s["category"],
                        priority=s["priority"],
                        enabled=s["enabled"],
                        version=s.get("version"),
                        metadata=s.get("metadata"),
                    )
                    for s in skills
                ]
                return {
                    "code": 200,
                    "message": "success",
                    "data": {"skills": skill_responses},
                }
        skills = await list_skills(category=category, enabled=enabled_bool, db=db)
        _skills_list_cache[cache_key] = (skills, now + _SKILLS_LIST_CACHE_TTL)

        skill_responses = [
            SkillResponse(
                skill_id=skill["skill_id"],
                name=skill["name"],
                description=skill.get("description"),
                category=skill["category"],
                priority=skill["priority"],
                enabled=skill["enabled"],
                version=skill.get("version"),
                metadata=skill.get("metadata")
            )
            for skill in skills
        ]
        
        return {
            "code": 200,
            "message": "success",
            "data": {
                "skills": skill_responses
            }
        }
    except Exception as e:
        logger.error(f"获取技能列表失败: {type(e).__name__}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取技能列表失败: {str(e)}"
        )


def _cover_filename(cover_image_val: str | None) -> str | None:
    """从完整 OSS URL 或 key 中提取文件名（用于 /skills/covers/{filename} 代理端点）"""
    if not cover_image_val:
        return None
    if cover_image_val.startswith("http"):
        from urllib.parse import urlparse
        return urlparse(cover_image_val).path.rstrip("/").rsplit("/", 1)[-1]
    return cover_image_val.rsplit("/", 1)[-1]


@router.get("/catalog", summary="获取技能目录（分类+子技能展开）")
async def get_skills_catalog(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    返回按一级分类分组、子技能展开的技能目录，合并用户选中状态。
    """
    try:
        skills = await list_skills(enabled=True, db=db)

        # 查询用户偏好
        selected_set: set = set()
        try:
            result = await db.execute(
                select(UserSkillPreference.skill_id).where(
                    UserSkillPreference.user_id == user_id,
                    UserSkillPreference.selected == True,
                )
            )
            selected_set = {row[0] for row in result.all()}
        except Exception as e:
            logger.warning(f"查询用户技能偏好失败: {e}")

        # 按分类收集展开后的子技能条目
        category_skills: Dict[str, list] = {c: [] for c in _CATALOG_CATEGORY_ORDER}

        for skill in skills:
            cat = skill["category"]
            # emotion 旧分类映射到 personal
            if cat in ("emotion", "personal"):
                cat = "personal"
            if cat not in category_skills:
                continue

            metadata = skill.get("metadata") or {}
            sub_skills = metadata.get("sub_skills", [])

            if sub_skills:
                for sub in sub_skills:
                    sub_id = sub.get("id", "")
                    category_skills[cat].append({
                        "skill_id": sub_id,
                        "parent_skill_id": skill["skill_id"],
                        "name": sub.get("name", sub_id),
                        "description": sub.get("description", ""),
                        "cover_color": sub.get("cover_color"),
                        "cover_image": _cover_filename(sub.get("cover_image")),
                        "video_url": None,
                        "selected": sub_id in selected_set,
                        "pro_content": sub.get("pro_content") or None,
                    })
            else:
                sid = skill["skill_id"]
                display_desc = metadata.get("display_description") or skill.get("description", "")
                cover_color = metadata.get("cover_color")
                category_skills[cat].append({
                    "skill_id": sid,
                    "parent_skill_id": None,
                    "name": skill["name"],
                    "description": display_desc,
                    "cover_color": cover_color,
                    "cover_image": None,
                    "video_url": None,
                    "selected": sid in selected_set,
                })

        categories = []
        for cat_id in _CATALOG_CATEGORY_ORDER:
            items = category_skills.get(cat_id, [])
            if not items:
                continue
            categories.append({
                "id": cat_id,
                "name": _CATALOG_CATEGORY_NAMES.get(cat_id, cat_id),
                "icon": _CATALOG_CATEGORY_ICONS.get(cat_id, "sparkles"),
                "skills": items,
            })

        return {"code": 200, "message": "success", "data": {"categories": categories}}
    except Exception as e:
        logger.error(f"获取技能目录失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取技能目录失败: {e}")


def _oss_key_from_cover_image(cover_image_val: str | None) -> str | None:
    """从 cover_image 值中提取 OSS key（支持完整 OSS URL 或已有 key 格式）"""
    if not cover_image_val:
        return None
    if cover_image_val.startswith("http"):
        # https://bucket.endpoint/skill_covers/foo_pixar.png → skill_covers/foo_pixar.png
        from urllib.parse import urlparse
        path = urlparse(cover_image_val).path.lstrip("/")
        return path
    return cover_image_val  # already a relative key


@router.get("/covers/{filename}", summary="技能封面图（公开，无需登录）", include_in_schema=False)
async def get_skill_cover(filename: str):
    """从私有 OSS 代理返回技能封面图，无需认证（封面为全局静态资源）"""
    try:
        import oss2
        auth = oss2.Auth(
            os.getenv("OSS_ACCESS_KEY_ID", ""),
            os.getenv("OSS_ACCESS_KEY_SECRET", ""),
        )
        bucket = oss2.Bucket(
            auth,
            os.getenv("OSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com"),
            os.getenv("OSS_BUCKET_NAME", "geminipicture2"),
        )
        oss_key = f"skill_covers/{filename}"
        obj = bucket.get_object(oss_key)
        data = obj.read()
        return Response(content=data, media_type="image/png",
                        headers={"Cache-Control": "public, max-age=86400"})
    except Exception as e:
        logger.error(f"技能封面获取失败 {filename}: {e}")
        raise HTTPException(status_code=404, detail="cover not found")


_MANUAL_MODE_KEY = "__manual_mode__"  # 用于在 user_skill_preferences 表中存储模式标记


@router.get("/preferences", summary="获取用户技能偏好")
async def get_skill_preferences(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    try:
        result = await db.execute(
            select(UserSkillPreference.skill_id).where(
                UserSkillPreference.user_id == user_id,
                UserSkillPreference.selected == True,
            )
        )
        rows = [row[0] for row in result.all()]
        is_manual_mode = _MANUAL_MODE_KEY in rows
        selected = [sid for sid in rows if sid != _MANUAL_MODE_KEY]
        return {"code": 200, "message": "success", "data": {
            "selected_skills": selected,
            "is_manual_mode": is_manual_mode,
        }}
    except Exception as e:
        logger.error(f"获取技能偏好失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/preferences", summary="更新用户技能偏好")
async def update_skill_preferences(
    body: SkillPreferencesUpdate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    try:
        # 若 is_manual_mode 为 None，保留原有模式设置
        if body.is_manual_mode is None:
            mode_result = await db.execute(
                select(UserSkillPreference.skill_id).where(
                    UserSkillPreference.user_id == user_id,
                    UserSkillPreference.skill_id == _MANUAL_MODE_KEY,
                    UserSkillPreference.selected == True,
                )
            )
            keep_manual = mode_result.scalar_one_or_none() is not None
        else:
            keep_manual = body.is_manual_mode

        await db.execute(
            delete(UserSkillPreference).where(UserSkillPreference.user_id == user_id)
        )
        for sid in body.selected_skills:
            if sid != _MANUAL_MODE_KEY:
                db.add(UserSkillPreference(user_id=user_id, skill_id=sid, selected=True))
        if keep_manual:
            db.add(UserSkillPreference(user_id=user_id, skill_id=_MANUAL_MODE_KEY, selected=True))
        await db.commit()
        return {"code": 200, "message": "success", "data": {
            "selected_skills": body.selected_skills,
            "is_manual_mode": keep_manual,
        }}
    except Exception as e:
        await db.rollback()
        logger.error(f"更新技能偏好失败: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{skill_id}", summary="获取特定技能详情")
async def get_skill_detail(
    skill_id: str,
    include_content: bool = False,  # 是否包含 SKILL.md 完整内容
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    获取特定技能的详细信息
    
    - **skill_id**: 技能 ID（如 "workplace_jungle"）
    - **include_content**: 是否包含 SKILL.md 完整内容（默认 false）
    """
    try:
        skill = await get_skill(skill_id, db)
        
        if not skill:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"技能不存在: {skill_id}"
            )
        
        response_data = {
            "skill_id": skill["skill_id"],
            "name": skill["name"],
            "description": skill.get("description"),
            "category": skill["category"],
            "skill_path": skill["skill_path"],
            "priority": skill["priority"],
            "enabled": skill["enabled"],
            "version": skill.get("version"),
            "metadata": skill.get("metadata")
        }
        
        # 如果请求包含完整内容，添加 SKILL.md 内容
        if include_content:
            response_data["content"] = skill.get("content", "")
            response_data["prompt_template"] = skill.get("prompt_template", "")
            response_data["knowledge_base"] = skill.get("knowledge_base")
        
        return {
            "code": 200,
            "message": "success",
            "data": response_data
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取技能详情失败: {skill_id}, 错误: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"获取技能详情失败: {str(e)}"
        )


@router.post("", summary="创建新技能", status_code=status.HTTP_201_CREATED)
async def create_skill(
    body: SkillCreate,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    在文件系统创建技能目录和 SKILL.md，并注册到数据库（与 v0.4 文档一致）
    """
    try:
        _invalidate_skills_list_cache()
        create_skill_file(
            skill_id=body.skill_id,
            name=body.name,
            description=body.description or "",
            category=body.category,
            priority=body.priority,
            enabled=body.enabled,
            version=body.version,
        )
        skill_info = await register_skill(body.skill_id, db)
        return {
            "code": 201,
            "message": "success",
            "data": {
                "skill_id": skill_info["skill_id"],
                "name": skill_info["name"],
                "description": skill_info.get("description"),
                "category": skill_info["category"],
                "priority": skill_info["priority"],
                "enabled": skill_info["enabled"],
                "version": skill_info.get("version"),
                "message": "技能已创建并注册",
            },
        }
    except FileExistsError:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"技能已存在: {body.skill_id}",
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"创建技能失败: {body.skill_id}, 错误: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"创建技能失败: {str(e)}",
        )


@router.put("/{skill_id}", summary="更新技能")
async def update_skill(
    skill_id: str,
    body: Optional[SkillUpdate] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    更新 SKILL.md 的 frontmatter 并刷新数据库缓存；若不传 body 则仅从文件系统重新加载。
    """
    try:
        _invalidate_skills_list_cache()
        if body is not None:
            update_skill_file(
                skill_id,
                name=body.name,
                description=body.description,
                category=body.category,
                priority=body.priority,
                enabled=body.enabled,
                version=body.version,
            )
        skill_info = await reload_skill(skill_id, db)
        return {
            "code": 200,
            "message": "success",
            "data": {
                "skill_id": skill_info["skill_id"],
                "name": skill_info["name"],
                "message": "技能已更新并重新加载",
            },
        }
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"技能不存在: {skill_id}",
        )
    except Exception as e:
        logger.error(f"更新技能失败: {skill_id}, 错误: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"更新技能失败: {str(e)}",
        )


@router.post("/{skill_id}/reload", summary="重新加载技能")
async def reload_skill_endpoint(
    skill_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    重新加载技能（从文件系统刷新数据库缓存）
    
    - **skill_id**: 技能 ID
    """
    try:
        _invalidate_skills_list_cache()
        skill_info = await reload_skill(skill_id, db)
        
        return {
            "code": 200,
            "message": "success",
            "data": {
                "skill_id": skill_info["skill_id"],
                "name": skill_info["name"],
                "message": "技能已重新加载"
            }
        }
    except FileNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"技能文件不存在: {skill_id}"
        )
    except Exception as e:
        logger.error(f"重新加载技能失败: {skill_id}, 错误: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"重新加载技能失败: {str(e)}"
        )
