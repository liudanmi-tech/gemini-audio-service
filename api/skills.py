"""
技能管理API接口
包括获取技能列表、技能详情、重新加载技能等
"""
import time
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import List, Optional, Dict, Tuple, Any

import logging

from database.connection import get_db
from auth.jwt_handler import get_current_user_id
from skills.registry import list_skills, get_skill, reload_skill, register_skill
from skills.loader import create_skill_file, update_skill_file

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
