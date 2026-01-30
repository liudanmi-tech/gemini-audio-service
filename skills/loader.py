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
        # 统一换行，避免 CRLF 导致 frontmatter / 代码块正则不匹配
        content = content.replace('\r\n', '\n').replace('\r', '\n')
        
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
    # 查找 "## Prompt模板" 部分（只在「新行开头的 ## 标题」处结束，避免被内容里的 ### 等截断）
    prompt_section_pattern = r'##\s*Prompt模板\s*\n(.*?)(?=\n##\s|\n##$|$)'
    match = re.search(prompt_section_pattern, markdown_content, re.DOTALL | re.IGNORECASE)
    
    if not match:
        raise ValueError("SKILL.md 中未找到 '## Prompt模板' 部分")
    
    prompt_section = match.group(1)
    # 统一换行为 \n，避免 CRLF 导致正则不匹配
    prompt_section = prompt_section.replace('\r\n', '\n').replace('\r', '\n')
    
    # 1) 正则提取 ```prompt 或 ``` 代码块
    for pattern in [
        r'```prompt\s*\n(.*?)```',
        r'```\s*\n(.*?)```',
    ]:
        match = re.search(pattern, prompt_section, re.DOTALL)
        if match:
            prompt_template = match.group(1).strip()
            if prompt_template:
                return prompt_template
    
    # 2) 兜底：按第一个 ``` 到下一个 ``` 截取（不依赖正则细节）
    start = prompt_section.find('```')
    if start >= 0:
        start = prompt_section.find('\n', start) + 1
        if start > 0:
            end = prompt_section.find('```', start)
            if end > start:
                prompt_template = prompt_section[start:end].strip()
                if prompt_template:
                    return prompt_template
    
    logger.debug("Prompt模板节内容长度=%s 前200字=%s", len(prompt_section), repr(prompt_section[:200]))
    raise ValueError("Prompt模板部分未找到代码块")


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


def create_skill_file(
    skill_id: str,
    name: str,
    description: str = "",
    category: str = "other",
    priority: int = 0,
    enabled: bool = True,
    version: str = "1.0.0",
) -> str:
    """
    在文件系统创建技能目录和最小 SKILL.md（供 API 创建技能使用）

    Args:
        skill_id: 技能 ID（仅允许字母、数字、下划线）
        name: 技能名称
        description: 描述
        category: 分类
        priority: 优先级
        enabled: 是否启用
        version: 版本号

    Returns:
        创建的 SKILL.md 路径
    """
    if not re.match(r"^[a-zA-Z][a-zA-Z0-9_]*$", skill_id):
        raise ValueError("skill_id 仅允许字母开头，字母、数字、下划线")
    skill_dir = SKILLS_ROOT / skill_id
    if skill_dir.exists():
        raise FileExistsError(f"技能目录已存在: {skill_id}")
    skill_dir.mkdir(parents=True, exist_ok=True)
    skill_md_path = skill_dir / "SKILL.md"
    frontmatter = {
        "name": name,
        "description": description,
        "category": category,
        "priority": priority,
        "enabled": enabled,
        "version": version,
        "keywords": [],
        "scenarios": [],
    }
    fm_text = yaml.dump(frontmatter, allow_unicode=True, default_flow_style=False, sort_keys=False)
    prompt_placeholder = "角色: 策略分析助手。\n任务: 根据对话转录生成策略与视觉描述。\n\n对话转录:\n{transcript_json}"
    content = f"---\n{fm_text}---\n\n# {name}\n\n## Prompt模板\n\n```prompt\n{prompt_placeholder}\n```\n"
    skill_md_path.write_text(content, encoding="utf-8")
    logger.info(f"已创建技能文件: {skill_md_path}")
    return str(skill_md_path)


def update_skill_file(
    skill_id: str,
    name: Optional[str] = None,
    description: Optional[str] = None,
    category: Optional[str] = None,
    priority: Optional[int] = None,
    enabled: Optional[bool] = None,
    version: Optional[str] = None,
) -> str:
    """
    更新 SKILL.md 的 frontmatter 字段（供 API 更新技能使用）

    Args:
        skill_id: 技能 ID
        其余: 要更新的字段，None 表示不更新

    Returns:
        更新后的 SKILL.md 路径
    """
    skill_md_path = SKILLS_ROOT / skill_id / "SKILL.md"
    if not skill_md_path.exists():
        raise FileNotFoundError(f"技能文件不存在: {skill_id}")
    parsed = parse_skill_markdown(str(skill_md_path))
    frontmatter = parsed["frontmatter"] or {}
    markdown_content = parsed["content"]
    if name is not None:
        frontmatter["name"] = name
    if description is not None:
        frontmatter["description"] = description
    if category is not None:
        frontmatter["category"] = category
    if priority is not None:
        frontmatter["priority"] = priority
    if enabled is not None:
        frontmatter["enabled"] = enabled
    if version is not None:
        frontmatter["version"] = version
    fm_text = yaml.dump(frontmatter, allow_unicode=True, default_flow_style=False, sort_keys=False)
    content = f"---\n{fm_text}---\n{markdown_content}"
    skill_md_path.write_text(content, encoding="utf-8")
    logger.info(f"已更新技能文件: {skill_md_path}")
    return str(skill_md_path)
