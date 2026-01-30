"""
场景路由器
实现场景识别和技能匹配功能
"""
import os
import json
import logging
from typing import List, Dict
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import google.generativeai as genai

from .registry import list_skills
from database.models import Skill

logger = logging.getLogger(__name__)

# 场景/策略模型名，可通过环境变量 GEMINI_FLASH_MODEL 覆盖
GEMINI_FLASH_MODEL = os.getenv("GEMINI_FLASH_MODEL", "gemini-3-flash-preview")


def classify_scene(transcript: list, model=None) -> Dict:
    """
    场景分类，调用 Gemini Router Agent
    
    Args:
        transcript: 对话转录列表
        model: Gemini 模型实例（如果为 None，则使用默认模型）
        
    Returns:
        dict: {
            "scenes": [
                {
                    "category": "workplace",
                    "confidence": 0.95,
                    "reasoning": "对话涉及项目汇报和截止日期讨论"
                }
            ],
            "primary_scene": "workplace"
        }
    """
    if model is None:
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
    
    router_prompt = """你是一个场景分类专家。请分析以下对话转录，识别对话发生的场景类型。

场景类型包括：
1. workplace (职场场景): 工作相关、上下级关系、同事协作、项目讨论
2. family (家庭场景): 夫妻关系、亲子关系、家庭决策
3. education (教育场景): 孩子教育、学习辅导、成长引导
4. brainstorm (头脑风暴): 创意讨论、方案设计、问题解决
5. other (其他场景): 无法明确分类的场景

请返回JSON格式：
{
  "scenes": [
    {
      "category": "workplace",
      "confidence": 0.95,
      "reasoning": "对话涉及项目汇报和截止日期讨论"
    },
    {
      "category": "family",
      "confidence": 0.3,
      "reasoning": "提到了家庭安排"
    }
  ],
  "primary_scene": "workplace"
}

对话转录:
{transcript_json}"""
    
    try:
        transcript_json = json.dumps(transcript, ensure_ascii=False, indent=2)
        prompt = router_prompt.format(transcript_json=transcript_json)
        
        logger.info("========== 开始场景识别 ==========")
        logger.debug(f"场景识别 Prompt 长度: {len(prompt)} 字符")
        
        response = model.generate_content(prompt)
        
        logger.info(f"场景识别响应长度: {len(response.text)} 字符")
        logger.debug(f"场景识别响应内容: {response.text[:500]}...")
        
        # 解析 JSON 响应
        try:
            # 尝试提取 JSON 部分（可能包含 markdown 代码块）
            response_text = response.text.strip()
            if response_text.startswith("```"):
                # 提取代码块中的内容
                import re
                json_match = re.search(r'```(?:json)?\s*\n(.*?)\n```', response_text, re.DOTALL)
                if json_match:
                    response_text = json_match.group(1)
            
            scene_result = json.loads(response_text)
            
            # 验证结果格式
            if "scenes" not in scene_result:
                raise ValueError("场景识别结果缺少 'scenes' 字段")
            if "primary_scene" not in scene_result:
                # 如果没有 primary_scene，从 scenes 中选择置信度最高的
                if scene_result["scenes"]:
                    primary_scene = max(scene_result["scenes"], key=lambda x: x.get("confidence", 0))
                    scene_result["primary_scene"] = primary_scene["category"]
                else:
                    scene_result["primary_scene"] = "other"
            
            logger.info(f"场景识别成功: primary_scene={scene_result['primary_scene']}")
            for scene in scene_result["scenes"]:
                logger.info(f"  - {scene['category']}: {scene.get('confidence', 0):.2f} ({scene.get('reasoning', '')})")
            
            return scene_result
        except json.JSONDecodeError as e:
            logger.error(f"解析场景识别结果失败: {e}")
            logger.error(f"响应内容: {response.text}")
            # 返回默认结果
            return {
                "scenes": [{"category": "other", "confidence": 0.5, "reasoning": "解析失败"}],
                "primary_scene": "other"
            }
    except Exception as e:
        logger.error(f"场景识别失败: {e}")
        # 返回默认结果
        return {
            "scenes": [{"category": "other", "confidence": 0.5, "reasoning": f"识别失败: {str(e)}"}],
            "primary_scene": "other"
        }


async def match_skills(scene_result: Dict, db: AsyncSession) -> List[Dict]:
    """
    根据场景分类结果匹配技能
    
    Args:
        scene_result: 场景分类结果（来自 classify_scene）
        db: 数据库会话
        
    Returns:
        List[dict]: 匹配的技能列表，按优先级和置信度排序
    """
    matched_skills = []
    
    # 获取所有启用的技能
    all_skills = await list_skills(enabled=True, db=db)
    
    # 根据场景匹配技能
    scenes = scene_result.get("scenes", [])
    primary_scene = scene_result.get("primary_scene", "other")
    
    # 筛选置信度 > 0.5 的场景
    valid_scenes = [s for s in scenes if s.get("confidence", 0) > 0.5]
    
    if not valid_scenes:
        # 如果没有高置信度场景，使用 primary_scene
        valid_scenes = [{"category": primary_scene, "confidence": 0.5}]
    
    # 匹配技能
    for scene in valid_scenes:
        category = scene.get("category", "other")
        confidence = scene.get("confidence", 0.5)
        
        logger.debug(f"匹配场景类别: {category}, 置信度: {confidence:.2f}")
        
        # 查找匹配分类的技能
        for skill in all_skills:
            if skill["category"] == category:
                matched_skills.append({
                    "skill_id": skill["skill_id"],
                    "name": skill["name"],
                    "category": skill["category"],
                    "priority": skill["priority"],
                    "confidence": confidence,
                    "scene_reasoning": scene.get("reasoning", "")
                })
                logger.debug(f"  ✅ 匹配到技能: {skill['skill_id']} ({skill.get('name', 'N/A')})")
    
    # 去重（同一个技能可能匹配多个场景）
    seen = set()
    unique_skills = []
    for skill in matched_skills:
        if skill["skill_id"] not in seen:
            seen.add(skill["skill_id"])
            unique_skills.append(skill)
    
    # 按优先级和置信度排序
    unique_skills.sort(key=lambda x: (x["priority"], x["confidence"]), reverse=True)
    
    logger.info(f"技能匹配完成: 匹配到 {len(unique_skills)} 个技能")
    for skill in unique_skills:
        logger.info(f"  ✅ 匹配到技能: {skill['skill_id']} (名称: {skill.get('name', 'N/A')}, priority={skill['priority']}, confidence={skill['confidence']:.2f})")
    
    return unique_skills
