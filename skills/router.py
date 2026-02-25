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
    场景分类 + 职场维度识别，调用 Gemini Router Agent（单次 LLM 调用）
    
    Returns:
        dict: {
            "scenes": [{"category": "workplace", "confidence": 0.95, "reasoning": "..."}],
            "primary_scene": "workplace",
            "workplace_dimensions": [
                {"dimension": "role_position", "sub_skill": "managing_up", "sub_skill_name": "向上管理", "confidence": 0.9, "reasoning": "..."}
            ]
        }
    """
    if model is None:
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
    
    router_prompt = """你是一个场景分类专家。请分析以下对话转录，完成两项任务：

## 任务一：顶级场景分类

场景类型包括：
1. workplace (职场场景): 工作相关、上下级关系、同事协作、项目讨论、客户沟通。若对话人涉及同事、领导、老板、上级、下属、经理、总监、主管、客户等，必须包含 workplace。
2. family (家庭场景): 夫妻关系、亲子关系、家庭决策、孩子教育、学习辅导。若对话参与者是家人（爸爸、妈妈、老婆、老公、孩子等），必须包含 family。
3. other (其他场景): 无法归为职场或家庭的场景。

规则：
- 一个对话可同时命中多个场景
- 若对话涉及职场角色，即使主场景是 other，也应加入 workplace（confidence >= 0.6）
- 若对话涉及家人，应加入 family（confidence >= 0.6）

## 任务二：职场维度识别（仅当 workplace 命中时）

如果对话命中 workplace，请进一步判断命中了以下哪些维度和子技能（可命中多个，选择最相关的 2-4 个）：

### 维度 1: role_position (角色方位)
- managing_up (向上管理): 与老板/领导/上级的互动，汇报、请示、争取资源
- managing_down (向下管理): 与下属/团队的互动，指导、委派、考核、反馈
- peer_collaboration (横向协作): 与同事/平级的互动，跨部门协调、合作
- external_communication (对外沟通): 与客户/合作方/外部人员的互动

### 维度 2: scenario (场景情境)
- conflict_resolution (冲突化解): 争吵、不满、矛盾、对峙
- negotiation (谈判博弈): 薪资谈判、资源争夺、条件交换
- presentation (汇报展示): 工作汇报、方案展示、述职演讲
- small_talk (闲聊社交): 职场闲聊、团建、饭局、破冰
- crisis_management (危机公关): 事故处理、追责、道歉、声誉修复

### 维度 3: psychology (心理风格)
- defensive (防御型): 用户在保护边界、被动退让、忍耐
- offensive (进攻型): 用户在主动出击、挑战、施压
- constructive (建设型): 双方在寻求合作、双赢、解决问题
- healing (治愈型): 安慰、支持、倾听、共情

### 维度 4: career_stage (职业阶段)
- rookie (新人小白): 用户表现为新人，在学习、请教、融入
- core_manager (骨干中层): 用户在执行、协调、管理、带队
- executive (高管领袖): 用户在做战略决策、全局布局

### 维度 5: capability (能力维度)
- logical_thinking (逻辑思维): 对话涉及结构化表达、论证、分析
- eq (情商): 对话涉及情绪管理、察言观色、委婉表达
- influence (影响力): 对话涉及说服、推动、号召、激励

请返回JSON格式：
{
  "scenes": [
    {"category": "workplace", "confidence": 0.95, "reasoning": "对话涉及项目汇报"},
    {"category": "family", "confidence": 0.3, "reasoning": "提到了家庭安排"}
  ],
  "primary_scene": "workplace",
  "workplace_dimensions": [
    {"dimension": "role_position", "sub_skill": "managing_up", "sub_skill_name": "向上管理", "confidence": 0.9, "reasoning": "对话是向领导汇报工作"},
    {"dimension": "scenario", "sub_skill": "presentation", "sub_skill_name": "汇报展示", "confidence": 0.85, "reasoning": "正在做工作汇报"},
    {"dimension": "psychology", "sub_skill": "defensive", "sub_skill_name": "防御型", "confidence": 0.7, "reasoning": "用户处于防御姿态"}
  ]
}

注意：
- workplace_dimensions 仅在 workplace 命中时填写，否则为空数组
- 选择 2-4 个最相关的维度，不要全部选择
- 每个维度最多选择 1 个子技能

对话转录:
{transcript_json}"""
    
    try:
        transcript_json = json.dumps(transcript, ensure_ascii=False, indent=2)
        prompt = router_prompt.replace("{transcript_json}", transcript_json)
        
        logger.info("========== 开始场景识别 ==========")
        logger.debug(f"场景识别 Prompt 长度: {len(prompt)} 字符")
        
        response = model.generate_content(prompt)
        
        logger.info(f"场景识别响应长度: {len(response.text)} 字符")
        logger.debug(f"场景识别响应内容: {response.text[:500]}...")
        
        try:
            import re
            response_text = response.text.strip()
            logger.info(f"场景识别原始响应(前300字): {response_text[:300]}")
            
            # 尝试多种方式提取 JSON
            parsed = None
            # 方式1: 直接解析
            try:
                parsed = json.loads(response_text)
            except json.JSONDecodeError:
                pass
            
            # 方式2: 去除 markdown 代码块
            if parsed is None:
                json_match = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', response_text, re.DOTALL)
                if json_match:
                    try:
                        parsed = json.loads(json_match.group(1).strip())
                    except json.JSONDecodeError:
                        pass
            
            # 方式3: 提取第一个 { ... } 块
            if parsed is None:
                brace_match = re.search(r'\{.*\}', response_text, re.DOTALL)
                if brace_match:
                    try:
                        parsed = json.loads(brace_match.group(0))
                    except json.JSONDecodeError:
                        pass
            
            if parsed is None:
                logger.error(f"所有JSON解析方式均失败, 原始响应: {response_text[:500]}")
                raise ValueError(f"无法解析JSON: {response_text[:100]}")
            
            scene_result = parsed
            
            if "scenes" not in scene_result:
                raise ValueError("场景识别结果缺少 'scenes' 字段")
            if "primary_scene" not in scene_result:
                if scene_result["scenes"]:
                    primary_scene = max(scene_result["scenes"], key=lambda x: x.get("confidence", 0))
                    scene_result["primary_scene"] = primary_scene["category"]
                else:
                    scene_result["primary_scene"] = "other"
            
            if "workplace_dimensions" not in scene_result:
                scene_result["workplace_dimensions"] = []
            
            logger.info(f"场景识别成功: primary_scene={scene_result['primary_scene']}")
            for scene in scene_result["scenes"]:
                logger.info(f"  - {scene['category']}: {scene.get('confidence', 0):.2f} ({scene.get('reasoning', '')})")
            for dim in scene_result.get("workplace_dimensions", []):
                logger.info(f"  - 职场维度: {dim.get('dimension','?')}/{dim.get('sub_skill','?')} ({dim.get('sub_skill_name', '?')}) confidence={dim.get('confidence', 0):.2f}")
            
            return scene_result
        except (json.JSONDecodeError, ValueError) as e:
            logger.error(f"解析场景识别结果失败: {e}")
            logger.error(f"响应内容: {response.text[:500]}")
            return {
                "scenes": [{"category": "other", "confidence": 0.5, "reasoning": "解析失败"}],
                "primary_scene": "other",
                "workplace_dimensions": []
            }
    except Exception as e:
        logger.error(f"场景识别失败: {e}")
        import traceback
        logger.error(f"异常详情: {traceback.format_exc()}")
        return {
            "scenes": [{"category": "other", "confidence": 0.5, "reasoning": f"识别失败: {str(e)}"}],
            "primary_scene": "other",
            "workplace_dimensions": []
        }


# 对话人关键词 -> 场景补充匹配（LLM 漏判时的兜底）
WORKPLACE_KEYWORDS = ("同事", "领导", "老板", "上级", "下属", "经理", "总监", "主管", "科长", "处长", "局长")
FAMILY_KEYWORDS = ("爸爸", "妈妈", "老婆", "老公", "孩子", "儿子", "女儿", "家人", "父亲", "母亲", "爹", "妈", "爸")


def _supplement_scenes_by_participants(transcript: list, scenes: list) -> list:
    """
    根据对话转录中的人称/角色关键词，补充 workplace/family 场景（用于 LLM 漏判时兜底）。
    """
    if not transcript:
        return scenes
    text_parts = []
    for item in transcript:
        t = item.get("text") or item.get("content") or item.get("speaker") or ""
        if isinstance(t, str):
            text_parts.append(t)
    full_text = " ".join(text_parts)
    existing_categories = {s.get("category") for s in scenes}
    supplements = []
    if any(kw in full_text for kw in WORKPLACE_KEYWORDS) and "workplace" not in existing_categories:
        supplements.append({"category": "workplace", "confidence": 0.6, "reasoning": "对话涉及同事/领导等职场角色（关键词补充）"})
    if any(kw in full_text for kw in FAMILY_KEYWORDS) and "family" not in existing_categories:
        supplements.append({"category": "family", "confidence": 0.6, "reasoning": "对话参与者或称呼为家人（关键词补充）"})
    if supplements:
        logger.info(f"参与者关键词补充场景: {[s['category'] for s in supplements]}")
        return scenes + supplements
    return scenes


# 防抑郁监控触发关键词（源于认知三联征 + 语言指纹）
_DEPRESSION_CRISIS_KEYWORDS = ["不想活", "想活了", "活不下去", "死了算了", "想死", "自杀"]
_DEPRESSION_GENERAL_KEYWORDS = [
    "搞砸", "没用", "失败", "我不配", "废物", "不行", "很差",
    "针对", "没意思", "不公平", "没办法", "讨厌", "都怪我",
    "完蛋", "没希望", "没救了", "不会好了",
    "总是", "绝对", "从来", "永远", "每次",
    "累", "烦", "焦虑", "抑郁", "崩溃", "压力大", "撑不住",
]


def _should_trigger_depression_prevention(transcript: list) -> bool:
    """仅当用户话术命中关键词时触发防抑郁监控"""
    user_lines = []
    for item in transcript:
        if item.get("is_me") is True:
            text = item.get("text", item.get("content", ""))
            if text:
                user_lines.append(text)
    user_text = "".join(user_lines)
    char_count = len(user_text.replace(" ", "").replace("\n", ""))
    # 强制触发：命中危机词
    for kw in _DEPRESSION_CRISIS_KEYWORDS:
        if kw in user_text:
            logger.info(f"防抑郁监控触发(危机词): 命中「{kw}」")
            return True
    # 一般触发：字数>=50 且命中任一一般词
    if char_count >= 50:
        for kw in _DEPRESSION_GENERAL_KEYWORDS:
            if kw in user_text:
                logger.info(f"防抑郁监控触发: 字数={char_count} 命中「{kw}」")
                return True
    return False


# 维度 skill_id 与 dimension 字段的映射
_DIMENSION_TO_SKILL = {
    "role_position": "workplace_role",
    "scenario": "workplace_scenario",
    "psychology": "workplace_psychology",
    "career_stage": "workplace_career",
    "capability": "workplace_capability",
}


async def match_skills(scene_result: Dict, db: AsyncSession, transcript: list = None) -> List[Dict]:
    """
    根据场景分类结果匹配技能（支持职场多维度匹配）
    
    职场场景使用维度级匹配：根据 workplace_dimensions 匹配对应的维度技能，
    并将 matched_sub_skill 信息传入技能上下文。
    其他场景（family 等）保持按 category 匹配。
    情绪技能（emotion）始终追加。
    
    Returns:
        List[dict]: 匹配的技能列表，每项包含 skill_id, name, category, priority,
                    confidence, scene_reasoning, 以及可选的 dimension, matched_sub_skill,
                    matched_sub_skill_id 字段
    """
    matched_skills = []
    
    all_skills = await list_skills(enabled=True, db=db)
    
    scenes = scene_result.get("scenes", [])
    primary_scene = scene_result.get("primary_scene", "other")
    workplace_dimensions = scene_result.get("workplace_dimensions", [])
    
    scenes = _supplement_scenes_by_participants(transcript or [], scenes)
    
    valid_scenes = sorted(
        [s for s in scenes if s.get("confidence", 0) > 0.3],
        key=lambda x: x.get("confidence", 0),
        reverse=True
    )[:3]
    
    if not valid_scenes:
        valid_scenes = [{"category": primary_scene, "confidence": 0.5}]
    
    workplace_matched = any(s.get("category") == "workplace" for s in valid_scenes)
    
    for scene in valid_scenes:
        category = scene.get("category", "other")
        confidence = scene.get("confidence", 0.5)
        
        logger.debug(f"匹配场景类别: {category}, 置信度: {confidence:.2f}")
        
        if category == "workplace":
            # 职场场景：按维度匹配
            if workplace_dimensions:
                for dim in workplace_dimensions:
                    dim_name = dim.get("dimension", "")
                    target_skill_id = _DIMENSION_TO_SKILL.get(dim_name)
                    if not target_skill_id:
                        logger.warning(f"未知维度: {dim_name}")
                        continue
                    
                    skill_info = next((s for s in all_skills if s["skill_id"] == target_skill_id), None)
                    if not skill_info:
                        logger.warning(f"维度技能未注册: {target_skill_id}")
                        continue
                    
                    matched_skills.append({
                        "skill_id": skill_info["skill_id"],
                        "name": skill_info["name"],
                        "category": "workplace",
                        "priority": skill_info["priority"],
                        "confidence": dim.get("confidence", confidence),
                        "scene_reasoning": dim.get("reasoning", ""),
                        "dimension": dim_name,
                        "matched_sub_skill": dim.get("sub_skill_name", ""),
                        "matched_sub_skill_id": dim.get("sub_skill", ""),
                    })
                    logger.debug(f"  ✅ 维度匹配: {target_skill_id} ({dim.get('sub_skill_name', '')})")
            else:
                # workplace_dimensions 为空时的兜底：匹配所有 workplace 维度技能
                for skill in all_skills:
                    if skill["category"] == "workplace":
                        matched_skills.append({
                            "skill_id": skill["skill_id"],
                            "name": skill["name"],
                            "category": "workplace",
                            "priority": skill["priority"],
                            "confidence": confidence,
                            "scene_reasoning": scene.get("reasoning", ""),
                            "dimension": skill.get("metadata", {}).get("dimension", ""),
                            "matched_sub_skill": "",
                            "matched_sub_skill_id": "",
                        })
        else:
            # 非职场场景（family 等）：按 category 匹配
            for skill in all_skills:
                if skill["category"] == category:
                    matched_skills.append({
                        "skill_id": skill["skill_id"],
                        "name": skill["name"],
                        "category": skill["category"],
                        "priority": skill["priority"],
                        "confidence": confidence,
                        "scene_reasoning": scene.get("reasoning", ""),
                    })
                    logger.debug(f"  ✅ 匹配到技能: {skill['skill_id']} ({skill.get('name', 'N/A')})")
    
    # 情绪识别技能：所有对话都运行（personal 类中 emotion_recognition / depression_prevention 不参与场景匹配）
    _EMOTION_SKILL_IDS = {"emotion_recognition", "depression_prevention"}
    matched_ids = {s["skill_id"] for s in matched_skills}
    for skill in all_skills:
        if skill["skill_id"] not in _EMOTION_SKILL_IDS or skill["skill_id"] in matched_ids:
            continue
        if skill["skill_id"] == "depression_prevention":
            if not _should_trigger_depression_prevention(transcript or []):
                logger.debug(f"  ⏭️ 跳过 depression_prevention: 未命中触发关键词")
                continue
        matched_skills.append({
            "skill_id": skill["skill_id"],
            "name": skill["name"],
            "category": skill["category"],
            "priority": skill["priority"],
            "confidence": 0.9,
            "scene_reasoning": "情绪识别适用于所有对话",
        })
        logger.debug(f"  ✅ 追加情绪技能: {skill['skill_id']}")
    
    # 去重
    seen = set()
    unique_skills = []
    for skill in matched_skills:
        if skill["skill_id"] not in seen:
            seen.add(skill["skill_id"])
            unique_skills.append(skill)
    
    unique_skills.sort(key=lambda x: (x["priority"], x["confidence"]), reverse=True)
    
    logger.info(f"技能匹配完成: 匹配到 {len(unique_skills)} 个技能")
    for skill in unique_skills:
        dim_info = f", dimension={skill.get('dimension', '')}/{skill.get('matched_sub_skill', '')}" if skill.get("dimension") else ""
        logger.info(f"  ✅ {skill['skill_id']} (名称: {skill.get('name', 'N/A')}, priority={skill['priority']}, confidence={skill['confidence']:.2f}{dim_info})")
    
    return unique_skills
