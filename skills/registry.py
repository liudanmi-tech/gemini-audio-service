"""
技能注册表
管理技能的数据库缓存，支持从文件系统加载和注册技能
"""
import os
import json
from pathlib import Path
from typing import List, Dict, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
import logging

from .loader import load_skill_from_file
from database.models import Skill

logger = logging.getLogger(__name__)

# 技能根目录
SKILLS_ROOT = Path(__file__).parent.parent / "skills"


async def register_skill(skill_id: str, db: AsyncSession) -> Dict:
    """
    从文件系统加载技能并注册到数据库
    
    Args:
        skill_id: 技能 ID
        db: 数据库会话
        
    Returns:
        dict: 技能信息
    """
    try:
        # 从文件系统加载技能
        skill_data = load_skill_from_file(skill_id)
        frontmatter = skill_data["frontmatter"]
        
        # 构建元数据
        metadata = {
            "keywords": frontmatter.get("keywords", []),
            "scenarios": frontmatter.get("scenarios", []),
            "dependencies": frontmatter.get("dependencies", []),
            "author": frontmatter.get("author", "")
        }
        
        # 检查数据库中是否已存在
        result = await db.execute(
            select(Skill).where(Skill.skill_id == skill_id)
        )
        existing_skill = result.scalar_one_or_none()
        
        if existing_skill:
            # 更新现有技能（含 prompt_template 落表）
            existing_skill.name = frontmatter.get("name", skill_id)
            existing_skill.description = frontmatter.get("description", "")
            existing_skill.category = frontmatter.get("category", "other")
            existing_skill.skill_path = skill_data["skill_path"]
            existing_skill.priority = frontmatter.get("priority", 0)
            existing_skill.enabled = frontmatter.get("enabled", True)
            existing_skill.version = frontmatter.get("version", "1.0.0")
            existing_skill.prompt_template = skill_data.get("prompt_template")
            existing_skill.meta_data = metadata
            existing_skill.updated_at = datetime.utcnow()
            
            await db.commit()
            logger.info(f"技能已更新: {skill_id}")
            
            return {
                "skill_id": existing_skill.skill_id,
                "name": existing_skill.name,
                "description": existing_skill.description,
                "category": existing_skill.category,
                "priority": existing_skill.priority,
                "enabled": existing_skill.enabled,
                "version": existing_skill.version,
                "metadata": existing_skill.meta_data
            }
        else:
            # 创建新技能（含 prompt_template 落表）
            new_skill = Skill(
                skill_id=skill_id,
                name=frontmatter.get("name", skill_id),
                description=frontmatter.get("description", ""),
                category=frontmatter.get("category", "other"),
                skill_path=skill_data["skill_path"],
                priority=frontmatter.get("priority", 0),
                enabled=frontmatter.get("enabled", True),
                version=frontmatter.get("version", "1.0.0"),
                prompt_template=skill_data.get("prompt_template"),
                meta_data=metadata
            )
            
            db.add(new_skill)
            await db.commit()
            logger.info(f"技能已注册: {skill_id}")
            
            return {
                "skill_id": new_skill.skill_id,
                "name": new_skill.name,
                "description": new_skill.description,
                "category": new_skill.category,
                "priority": new_skill.priority,
                "enabled": new_skill.enabled,
                "version": new_skill.version,
                "metadata": new_skill.meta_data
            }
    except Exception as e:
        logger.error(f"注册技能失败: {skill_id}, 错误: {e}")
        await db.rollback()
        raise


async def get_skill(skill_id: str, db: AsyncSession) -> Optional[Dict]:
    """
    从数据库获取技能（如果不存在则从文件系统加载）
    
    Args:
        skill_id: 技能 ID
        db: 数据库会话
        
    Returns:
        dict: 技能信息（包含 prompt_template），如果不存在返回 None
    """
    # 先从数据库查询
    result = await db.execute(
        select(Skill).where(Skill.skill_id == skill_id)
    )
    db_skill = result.scalar_one_or_none()
    
    if db_skill:
        # 优先用表里的 prompt_template（落表后查表即可，不依赖文件）
        prompt_template = getattr(db_skill, "prompt_template", None) or ""
        knowledge_base = None
        if not (prompt_template and prompt_template.strip()):
            try:
                skill_data = load_skill_from_file(skill_id)
                prompt_template = skill_data.get("prompt_template") or ""
                knowledge_base = skill_data.get("knowledge_base")
            except Exception as e:
                logger.warning(f"技能文件加载失败且表内无 prompt_template: {skill_id}, {e}")
                return None
        else:
            try:
                knowledge_base = load_skill_from_file(skill_id).get("knowledge_base")
            except Exception:
                pass
        return {
            "skill_id": db_skill.skill_id,
            "name": db_skill.name,
            "description": db_skill.description,
            "category": db_skill.category,
            "skill_path": db_skill.skill_path,
            "priority": db_skill.priority,
            "enabled": db_skill.enabled,
            "version": db_skill.version,
            "metadata": db_skill.meta_data,
            "prompt_template": prompt_template,
            "knowledge_base": knowledge_base
        }
    else:
        # 数据库中没有，尝试从文件系统加载并注册
        try:
            await register_skill(skill_id, db)
            return await get_skill(skill_id, db)
        except Exception as e:
            logger.error(f"从文件系统加载技能失败: {skill_id}, 错误: {e}")
            return None


async def list_skills(category: Optional[str] = None, enabled: Optional[bool] = True, db: AsyncSession = None) -> List[Dict]:
    """
    列出所有可用技能
    
    Args:
        category: 技能分类（可选）
        enabled: 是否只返回启用的技能
        db: 数据库会话（可选，如果为 None 则从文件系统扫描）
        
    Returns:
        List[dict]: 技能列表
    """
    if db is None:
        # 从文件系统扫描
        skills = []
        if SKILLS_ROOT.exists():
            for skill_dir in SKILLS_ROOT.iterdir():
                if skill_dir.is_dir() and (skill_dir / "SKILL.md").exists():
                    try:
                        skill_data = load_skill_from_file(skill_dir.name)
                        frontmatter = skill_data["frontmatter"]
                        
                        if category and frontmatter.get("category") != category:
                            continue
                        if enabled and not frontmatter.get("enabled", True):
                            continue
                        
                        skills.append({
                            "skill_id": skill_dir.name,
                            "name": frontmatter.get("name", skill_dir.name),
                            "description": frontmatter.get("description", ""),
                            "category": frontmatter.get("category", "other"),
                            "priority": frontmatter.get("priority", 0),
                            "enabled": frontmatter.get("enabled", True),
                            "version": frontmatter.get("version", "1.0.0")
                        })
                    except Exception as e:
                        logger.warning(f"加载技能失败: {skill_dir.name}, 错误: {e}")
        
        return sorted(skills, key=lambda x: x["priority"], reverse=True)
    else:
        # 从数据库查询
        query = select(Skill)
        
        if category:
            query = query.where(Skill.category == category)
        if enabled is not None:
            query = query.where(Skill.enabled == (enabled is True))
        
        result = await db.execute(query)
        db_skills = result.scalars().all()
        
        skills = []
        for db_skill in db_skills:
            skills.append({
                "skill_id": db_skill.skill_id,
                "name": db_skill.name,
                "description": db_skill.description,
                "category": db_skill.category,
                "priority": db_skill.priority,
                "enabled": db_skill.enabled,
                "version": db_skill.version,
                "metadata": db_skill.meta_data
            })
        
        return sorted(skills, key=lambda x: x["priority"], reverse=True)


async def reload_skill(skill_id: str, db: AsyncSession) -> Dict:
    """
    重新加载技能（从文件系统刷新数据库缓存）
    
    Args:
        skill_id: 技能 ID
        db: 数据库会话
        
    Returns:
        dict: 更新后的技能信息
    """
    return await register_skill(skill_id, db)


async def initialize_skills(db: AsyncSession) -> List[Dict]:
    """
    初始化技能：尝试从文件注册，解析失败则跳过；表中已有记录则查表即用，缺 prompt_template 时尝试从文件回填。
    """
    if not SKILLS_ROOT.exists():
        logger.warning(f"技能目录不存在: {SKILLS_ROOT}")
        return await list_skills(db=db, enabled=None)
    
    for skill_dir in SKILLS_ROOT.iterdir():
        if skill_dir.is_dir() and (skill_dir / "SKILL.md").exists():
            skill_id = skill_dir.name
            try:
                await register_skill(skill_id, db)
                logger.info(f"技能初始化成功: {skill_id}")
            except Exception as e:
                logger.warning(f"技能从文件注册失败（已落表则查表可用）: {skill_id}, {e}")
    
    # 回填：表中已有技能但 prompt_template 为空时，尝试从文件写入一次
    result = await db.execute(select(Skill).where(Skill.enabled == True))
    for row in result.scalars().all():
        pt = getattr(row, "prompt_template", None)
        if pt and str(pt).strip():
            continue
        try:
            skill_data = load_skill_from_file(row.skill_id)
            template = skill_data.get("prompt_template")
            if template:
                row.prompt_template = template
                await db.commit()
                logger.info(f"技能 prompt_template 已回填: {row.skill_id}")
        except Exception as e:
            logger.debug(f"技能 prompt_template 回填跳过: {row.skill_id}, {e}")
    
    skills_in_db = await list_skills(db=db, enabled=True)
    logger.info(f"技能初始化完成，共注册 {len(skills_in_db)} 个技能")
    return skills_in_db
