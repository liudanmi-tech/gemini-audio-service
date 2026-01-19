"""
技能模块
提供技能加载、注册、路由、执行和组合功能
"""

from .loader import load_skill_from_file, parse_skill_markdown, extract_prompt_template, load_knowledge_base
from .registry import register_skill, get_skill, list_skills, reload_skill, initialize_skills
from .router import classify_scene, match_skills
from .executor import execute_skill, execute_skill_scripts
from .composer import compose_results

__all__ = [
    # loader
    'load_skill_from_file',
    'parse_skill_markdown',
    'extract_prompt_template',
    'load_knowledge_base',
    # registry
    'register_skill',
    'get_skill',
    'list_skills',
    'reload_skill',
    'initialize_skills',
    # router
    'classify_scene',
    'match_skills',
    # executor
    'execute_skill',
    'execute_skill_scripts',
    # composer
    'compose_results',
]
