"""
技能加载器
解析 SKILL.md 文件，提取 frontmatter 和 Prompt 模板
"""
import os
import re
import yaml
from pathlib import Path
from typing import Dict, Optional
import logging

logger = logging.getLogger(__name__)

# 技能根目录
SKILLS_ROOT = Path(__file__).parent.parent / "skills"


def parse_skill_markdown(skill_path: str) -> Dict:
    """
    解析 SKILL.md 文件，提取 frontmatter 和 Prompt 模板
    
    Args:
        skill_path: SKILL.md 文件的完整路径
        
    Returns:
        dict: {
            "frontmatter": {...},  # YAML frontmatter 内容
            "prompt_template": "...",  # Prompt 模板内容
            "content": "..."  # 完整的 Markdown 内容
        }
    """
    try:
        with open(skill_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # 解析 YAML frontmatter
        frontmatter_pattern = r'^---\s*\n(.*?)\n---\s*\n(.*)$'
        match = re.match(frontmatter_pattern, content, re.DOTALL)
        
        if not match:
            raise ValueError(f"SKILL.md 文件格式错误，缺少 YAML frontmatter: {skill_path}")
        
        frontmatter_text = match.group(1)
        markdown_content = match.group(2)
        
        # 解析 YAML
        try:
            frontmatter = yaml.safe_load(frontmatter_text)
            if frontmatter is None:
                frontmatter = {}
        except yaml.YAMLError as e:
            logger.error(f"解析 YAML frontmatter 失败: {e}")
            raise ValueError(f"YAML frontmatter 格式错误: {e}")
        
        # 提取 Prompt 模板
        prompt_template = extract_prompt_template(markdown_content)
        
        return {
            "frontmatter": frontmatter,
            "prompt_template": prompt_template,
            "content": markdown_content
        }
    except FileNotFoundError:
        raise FileNotFoundError(f"技能文件不存在: {skill_path}")
    except Exception as e:
        logger.error(f"解析技能文件失败: {skill_path}, 错误: {e}")
        raise


def extract_prompt_template(markdown_content: str) -> str:
    """
    从 Markdown 内容中提取 Prompt 模板
    
    查找 "## Prompt模板" 部分，提取 ```prompt 代码块中的内容
    
    Args:
        markdown_content: Markdown 内容
        
    Returns:
        str: Prompt 模板内容
    """
    # 查找 "## Prompt模板" 部分
    prompt_section_pattern = r'##\s*Prompt模板\s*\n(.*?)(?=##|$)'
    match = re.search(prompt_section_pattern, markdown_content, re.DOTALL | re.IGNORECASE)
    
    if not match:
        raise ValueError("SKILL.md 中未找到 '## Prompt模板' 部分")
    
    prompt_section = match.group(1)
    
    # 提取 ```prompt 代码块中的内容
    prompt_block_pattern = r'```prompt\s*\n(.*?)```'
    match = re.search(prompt_block_pattern, prompt_section, re.DOTALL)
    
    if not match:
        # 如果没有找到 ```prompt 代码块，尝试查找 ``` 代码块
        code_block_pattern = r'```\s*\n(.*?)```'
        match = re.search(code_block_pattern, prompt_section, re.DOTALL)
        if not match:
            raise ValueError("Prompt模板部分未找到代码块")
    
    prompt_template = match.group(1).strip()
    return prompt_template


def load_knowledge_base(skill_id: str) -> Optional[str]:
    """
    从 references/knowledge_base.md 读取知识库内容（可选）
    
    Args:
        skill_id: 技能 ID
        
    Returns:
        str: 知识库内容，如果文件不存在返回 None
    """
    knowledge_base_path = SKILLS_ROOT / skill_id / "references" / "knowledge_base.md"
    
    if not knowledge_base_path.exists():
        return None
    
    try:
        with open(knowledge_base_path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        logger.warning(f"读取知识库失败: {knowledge_base_path}, 错误: {e}")
        return None


def load_skill_from_file(skill_id: str) -> Dict:
    """
    从文件系统加载完整的技能信息
    
    Args:
        skill_id: 技能 ID（如 "workplace_jungle"）
        
    Returns:
        dict: {
            "skill_id": "workplace_jungle",
            "frontmatter": {...},
            "prompt_template": "...",
            "knowledge_base": "..." (可选),
            "skill_path": "skills/workplace_jungle"
        }
    """
    skill_dir = SKILLS_ROOT / skill_id
    skill_md_path = skill_dir / "SKILL.md"
    
    if not skill_md_path.exists():
        raise FileNotFoundError(f"技能文件不存在: {skill_md_path}")
    
    # 解析 SKILL.md
    parsed = parse_skill_markdown(str(skill_md_path))
    
    # 加载知识库（可选）
    knowledge_base = load_knowledge_base(skill_id)
    
    result = {
        "skill_id": skill_id,
        "frontmatter": parsed["frontmatter"],
        "prompt_template": parsed["prompt_template"],
        "skill_path": f"skills/{skill_id}",
        "content": parsed["content"]
    }
    
    if knowledge_base:
        result["knowledge_base"] = knowledge_base
    
    return result
