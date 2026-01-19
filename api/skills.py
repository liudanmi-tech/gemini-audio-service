"""
技能管理API接口
包括获取技能列表、技能详情、重新加载技能等
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import List, Optional
import logging

from database.connection import get_db
from auth.jwt_handler import get_current_user_id
from skills.registry import list_skills, get_skill, reload_skill

logger = logging.getLogger(__name__)

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


@router.get("", summary="获取所有可用技能")
async def get_all_skills(
    category: Optional[str] = None,
    enabled: bool = True,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    获取所有可用技能
    
    - **category**: 可选，按分类筛选（workplace/family/education/brainstorm）
    - **enabled**: 是否只返回启用的技能（默认 true）
    """
    try:
        skills = await list_skills(category=category, enabled=enabled, db=db)
        
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
        logger.error(f"获取技能列表失败: {e}")
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
