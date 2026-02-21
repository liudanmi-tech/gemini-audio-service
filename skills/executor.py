"""
技能执行器
执行技能，动态组装 Prompt 并生成策略
"""
import os
import json
import re
import time
import logging
from typing import Dict, List, Optional
import google.generativeai as genai

from .loader import load_knowledge_base
from schemas.strategy_schemas import parse_gemini_response, VisualData, StrategyItem, Call2Response

logger = logging.getLogger(__name__)

# 策略模型名，可通过环境变量 GEMINI_FLASH_MODEL 覆盖
GEMINI_FLASH_MODEL = os.getenv("GEMINI_FLASH_MODEL", "gemini-3-flash-preview")

# 情绪状态 -> emoji 映射（与 SKILL.md 一致）
MOOD_EMOJI_MAP = {
    "高兴": "😊",
    "焦虑": "😰",
    "平常心": "😐",
    "亢奋": "🤩",
    "悲伤": "😢",
}


def execute_skill_scripts(skill_id: str, script_name: str, input_data: dict) -> dict:
    """
    执行技能 scripts 目录下的代码（预处理/后处理）
    
    注意：为了安全，这个功能暂时不实现，或者需要严格的沙箱环境
    
    Args:
        skill_id: 技能 ID
        script_name: 脚本名称（如 "preprocess.py"）
        input_data: 输入数据
        
    Returns:
        dict: 处理后的数据
    """
    # TODO: 实现脚本执行功能（需要安全沙箱）
    logger.warning(f"脚本执行功能暂未实现: {skill_id}/{script_name}")
    return input_data


def _extract_emotion_counts(user_text: str) -> dict:
    """从用户话术中提取叹气、哈哈哈次数和字数（规则统计）"""
    sigh_pattern = re.compile(r'唉|哎|唉声叹气|唉呀|哎呦|哎哟', re.IGNORECASE)
    haha_pattern = re.compile(r'哈哈+|呵呵+|嘿哈|嘻哈', re.IGNORECASE)
    sigh_count = len(sigh_pattern.findall(user_text))
    haha_count = len(haha_pattern.findall(user_text))
    char_count = len(user_text.replace(" ", "").replace("\n", ""))
    return {"sigh_count": sigh_count, "haha_count": haha_count, "char_count": char_count}


async def _execute_emotion_skill(
    skill: Dict,
    transcript: List[Dict],
    context: Dict,
    model=None
) -> Dict:
    """执行情绪识别技能：提取用户话术，规则统计+LLM判断状态"""
    if model is None:
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
    skill_id = skill.get("skill_id", "emotion_recognition")
    skill_name = skill.get("name", "情绪识别")
    prompt_template = skill.get("prompt_template", "")
    start_time = time.time()
    
    try:
        # 1. 提取用户自己的话术（is_me=True）
        user_lines = []
        for item in transcript:
            if item.get("is_me") is True:
                text = item.get("text", item.get("content", ""))
                if text:
                    user_lines.append(text)
        user_text = "\n".join(user_lines) if user_lines else ""
        
        # 2. 规则统计
        counts = _extract_emotion_counts(user_text)
        sigh_count = counts["sigh_count"]
        haha_count = counts["haha_count"]
        char_count = counts["char_count"]
        
        # 3. LLM 判断 mood_state（若用户无话则默认平常心）
        mood_state = "平常心"
        mood_emoji = "😐"
        if user_text.strip():
            prompt = prompt_template.replace("{transcript_json}", json.dumps(user_lines, ensure_ascii=False, indent=2))
            prompt = prompt.replace("{session_id}", context.get("session_id", ""))
            prompt = prompt.replace("{user_id}", context.get("user_id", ""))
            prompt = prompt.replace("{memory_context}", context.get("memory_context", ""))
            response = model.generate_content(prompt)
            try:
                data = parse_gemini_response(response.text)
                if isinstance(data, dict):
                    raw_state = data.get("mood_state", "平常心")
                    mood_state = raw_state if raw_state in MOOD_EMOJI_MAP else "平常心"
                    mood_emoji = data.get("mood_emoji", MOOD_EMOJI_MAP.get(mood_state, "😐"))
            except Exception as e:
                logger.warning(f"情绪 LLM 解析失败，使用默认: {e}")
        
        execution_time_ms = int((time.time() - start_time) * 1000)
        emotion_insight = {
            "sigh_count": sigh_count,
            "haha_count": haha_count,
            "mood_state": mood_state,
            "mood_emoji": mood_emoji,
            "char_count": char_count,
        }
        logger.info(f"情绪识别完成: sigh={sigh_count} haha={haha_count} mood={mood_state} chars={char_count}")
        return {
            "skill_id": skill_id,
            "name": skill_name,
            "result": None,
            "emotion_insight": emotion_insight,
            "execution_time_ms": execution_time_ms,
            "success": True,
            "priority": skill.get("priority", 50),
            "confidence": skill.get("confidence", 0.9),
        }
    except Exception as e:
        execution_time_ms = int((time.time() - start_time) * 1000) if 'start_time' in locals() else 0
        logger.error(f"情绪识别失败: {e}")
        return {
            "skill_id": skill_id,
            "name": skill_name,
            "result": None,
            "emotion_insight": None,
            "execution_time_ms": execution_time_ms,
            "success": False,
            "error_message": str(e),
            "priority": skill.get("priority", 50),
            "confidence": skill.get("confidence", 0.9),
        }


async def _execute_depression_skill(
    skill: Dict,
    transcript: List[Dict],
    context: Dict,
    model=None
) -> Dict:
    """执行防抑郁监控技能：解析 LLM 返回的 JSON，输出 mental_health_insight"""
    if model is None:
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
    skill_id = skill.get("skill_id", "depression_prevention")
    skill_name = skill.get("name", "防抑郁监控")
    prompt_template = skill.get("prompt_template", "")
    start_time = time.time()

    try:
        # 1. 提取用户自己的话术（is_me=True）
        user_lines = []
        for item in transcript:
            if item.get("is_me") is True:
                text = item.get("text", item.get("content", ""))
                if text:
                    user_lines.append(text)
        user_text = "\n".join(user_lines) if user_lines else ""

        if not user_text.strip():
            logger.info(f"防抑郁监控跳过: 用户无话术")
            return {
                "skill_id": skill_id,
                "name": skill_name,
                "result": None,
                "mental_health_insight": None,
                "execution_time_ms": int((time.time() - start_time) * 1000),
                "success": False,
                "error_message": "用户无话术",
                "priority": skill.get("priority", 45),
                "confidence": skill.get("confidence", 0.9),
            }

        # 2. 组装 prompt 并调用 LLM
        prompt = prompt_template.replace("{transcript_json}", json.dumps(user_lines, ensure_ascii=False, indent=2))
        prompt = prompt.replace("{session_id}", context.get("session_id", ""))
        prompt = prompt.replace("{user_id}", context.get("user_id", ""))
        prompt = prompt.replace("{memory_context}", context.get("memory_context", ""))
        response = model.generate_content(prompt)

        # 3. 解析 JSON 响应
        data = parse_gemini_response(response.text)
        if not isinstance(data, dict):
            raise ValueError("LLM 未返回有效 JSON 对象")

        # 4. 构建 mental_health_insight 结构
        triad = data.get("cognitive_triad", {}) or {}
        mental_health_insight = {
            "defense_energy_pct": data.get("defense_energy_pct", 50),
            "dominant_defense": data.get("dominant_defense", ""),
            "status_assessment": data.get("status_assessment", ""),
            "cognitive_triad": {
                "self": triad.get("self", {"status": "green", "reason": ""}),
                "world": triad.get("world", {"status": "green", "reason": ""}),
                "future": triad.get("future", {"status": "green", "reason": ""}),
            },
            "insight": data.get("insight", ""),
            "strategy": data.get("strategy", ""),
            "crisis_alert": data.get("crisis_alert", False),
        }

        execution_time_ms = int((time.time() - start_time) * 1000)
        logger.info(f"防抑郁监控完成: crisis_alert={mental_health_insight['crisis_alert']} energy={mental_health_insight['defense_energy_pct']}%")
        return {
            "skill_id": skill_id,
            "name": skill_name,
            "result": None,
            "mental_health_insight": mental_health_insight,
            "execution_time_ms": execution_time_ms,
            "success": True,
            "priority": skill.get("priority", 45),
            "confidence": skill.get("confidence", 0.9),
        }
    except Exception as e:
        execution_time_ms = int((time.time() - start_time) * 1000) if 'start_time' in locals() else 0
        logger.error(f"防抑郁监控失败: {e}")
        return {
            "skill_id": skill_id,
            "name": skill_name,
            "result": None,
            "mental_health_insight": None,
            "execution_time_ms": execution_time_ms,
            "success": False,
            "error_message": str(e),
            "priority": skill.get("priority", 45),
            "confidence": skill.get("confidence", 0.9),
        }


async def execute_skill(
    skill: Dict,
    transcript: List[Dict],
    context: Dict,
    model=None
) -> Dict:
    """
    执行单个技能

    Args:
        skill: 技能信息（包含 prompt_template）
        transcript: 对话转录列表
        context: 上下文信息（包含 session_id, user_id 等）
        model: Gemini 模型实例（如果为 None，则使用默认模型）
        
    Returns:
        dict: 策略分析结果（Call2Response 格式）或 emotion_insight（情绪技能）
    """
    skill_id = skill.get("skill_id", "unknown")
    if skill_id == "emotion_recognition":
        return await _execute_emotion_skill(skill, transcript, context, model)
    if skill_id == "depression_prevention":
        return await _execute_depression_skill(skill, transcript, context, model)
    
    if model is None:
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
    
    prompt_template = skill.get("prompt_template", "")
    
    if not prompt_template:
        raise ValueError(f"技能 {skill_id} 缺少 prompt_template")
    
    try:
        skill_name = skill.get("name", skill_id)
        logger.info(f"========== 开始执行技能: {skill_id} (名称: {skill_name}) ==========")
        start_time = time.time()
        
        # 1. 预处理（可选）
        # TODO: 如果存在 scripts/preprocess.py，执行预处理
        processed_transcript = transcript
        
        # 2. Prompt 组装
        transcript_json = json.dumps(processed_transcript, ensure_ascii=False, indent=2)
        
        # 替换变量
        prompt = prompt_template.replace("{transcript_json}", transcript_json)
        prompt = prompt.replace("{session_id}", context.get("session_id", ""))
        prompt = prompt.replace("{user_id}", context.get("user_id", ""))
        # v0.6 记忆：注入 memory_context，若无则填空（向后兼容）
        memory_context = context.get("memory_context", "")
        has_memory = bool(memory_context and memory_context.strip())
        if has_memory:
            logger.info(f"[记忆] 技能 {skill_id} 注入 memory_context: len={len(memory_context)} preview={memory_context[:150]}...")
        elif "{memory_context}" in prompt_template:
            logger.info(f"[记忆] 技能 {skill_id} memory_context 为空，占位符将填空")
        prompt = prompt.replace("{memory_context}", memory_context)
        
        # 3. 知识库注入（可选）
        knowledge_base = skill.get("knowledge_base")
        if knowledge_base:
            # 在 Prompt 末尾添加知识库内容
            prompt += f"\n\n## 知识库参考\n{knowledge_base}"
        
        logger.info(f"Prompt 长度: {len(prompt)} 字符")
        logger.debug(f"Prompt 内容: {prompt[:500]}...")
        
        # 4. 调用 Gemini 生成策略
        logger.info(f"调用模型: {GEMINI_FLASH_MODEL}")
        response = model.generate_content(prompt)
        
        logger.info(f"Gemini 响应长度: {len(response.text)} 字符")
        logger.debug(f"Gemini 响应内容: {response.text[:1000]}...")
        
        # 5. 解析响应
        try:
            analysis_data = parse_gemini_response(response.text)
        except Exception as e:
            logger.error(f"解析 Gemini 响应失败: {e}")
            logger.error(f"响应内容: {response.text}")
            raise Exception(f"解析策略分析结果失败: {str(e)}")
        
        # 6. 验证解析结果
        if not isinstance(analysis_data, dict):
            logger.error(f"解析结果不是字典类型: {type(analysis_data)}, 内容: {analysis_data}")
            raise Exception("策略分析结果格式错误")
        
        if "visual" not in analysis_data:
            logger.error(f"缺少 'visual' 字段，可用字段: {list(analysis_data.keys())}")
            raise Exception("策略分析结果缺少 'visual' 字段")
        
        if "strategies" not in analysis_data:
            logger.error(f"缺少 'strategies' 字段，可用字段: {list(analysis_data.keys())}")
            raise Exception("策略分析结果缺少 'strategies' 字段")
        
        # 7. 处理 visual 数据
        visual_raw = analysis_data.get("visual")
        
        # 向后兼容：如果返回的是单个对象，转换为数组
        if isinstance(visual_raw, dict):
            logger.warning("收到单个 visual 对象，转换为数组格式以保持兼容")
            visual_raw = [visual_raw]
        elif not isinstance(visual_raw, list):
            logger.error(f"visual 字段格式错误，期望数组或对象，实际类型: {type(visual_raw)}")
            raise Exception("visual 字段必须是数组或对象")
        
        # 验证 visual 数组不为空
        if len(visual_raw) == 0:
            logger.warning("visual 数组为空，创建默认 visual")
            if transcript:
                first_item = transcript[0]
                visual_raw = [{
                    "transcript_index": 0,
                    "speaker": first_item.get("speaker", "Speaker_0"),
                    "image_prompt": "宫崎骏吉卜力动画风格，温暖自然色调。左侧为用户，右侧为对方。",
                    "emotion": "未知",
                    "subtext": "",
                    "context": "对话开始",
                    "my_inner": "",
                    "other_inner": ""
                }]
            else:
                raise Exception("visual 数组为空且无法创建默认值")
        
        # 验证关键时刻数量（2-5 个）
        if len(visual_raw) > 5:
            logger.warning(f"关键时刻数量过多 ({len(visual_raw)} 个)，只保留前 5 个")
            visual_raw = visual_raw[:5]
        elif len(visual_raw) < 3:
            logger.warning(f"关键时刻数量较少 ({len(visual_raw)} 个)，将尝试从策略补足至至少 3 个")
        
        # 构建 VisualData 列表
        visual_list = []
        transcript_length = len(transcript)
        
        try:
            for idx, v in enumerate(visual_raw):
                # 验证 transcript_index
                transcript_index = v.get("transcript_index", idx)
                if transcript_index < 0 or transcript_index >= transcript_length:
                    logger.warning(f"transcript_index {transcript_index} 超出范围 (0-{transcript_length-1})，使用索引 {idx}")
                    transcript_index = min(idx, transcript_length - 1) if transcript_length > 0 else 0
                
                # 获取对应的 transcript 项以获取 speaker
                speaker = v.get("speaker", "")
                if not speaker and transcript_length > 0:
                    speaker = transcript[transcript_index].get("speaker", "Speaker_0")
                
                visual_data = VisualData(
                    transcript_index=transcript_index,
                    speaker=speaker,
                    image_prompt=v.get("image_prompt", ""),
                    emotion=v.get("emotion", ""),
                    subtext=v.get("subtext", ""),
                    context=v.get("context", ""),
                    my_inner=v.get("my_inner", ""),
                    other_inner=v.get("other_inner", "")
                )
                visual_list.append(visual_data)
        except Exception as e:
            logger.error(f"构建 VisualData 列表失败: {e}")
            logger.error(f"visual 数据: {visual_raw}")
            raise Exception(f"构建视觉数据失败: {str(e)}")
        
        # 构建策略列表（需在补足 visual 前完成，因补足逻辑依赖 strategies）
        strategies_list = []
        try:
            for s in analysis_data.get("strategies", []):
                strategies_list.append(StrategyItem(
                    id=s.get("id", ""),
                    label=s.get("label", ""),
                    emoji=s.get("emoji", ""),
                    title=s.get("title", ""),
                    content=s.get("content", "")
                ))
        except Exception as e:
            logger.error(f"构建策略列表失败: {e}")
            logger.error(f"strategies 数据: {analysis_data.get('strategies')}")
            raise Exception(f"构建策略列表失败: {str(e)}")
        
        # 7b. 兜底：不足 3 个 visual 时，从 strategies 补足（推荐策略类图片）
        if len(visual_list) < 3 and strategies_list:
            strategies_to_use = [s for s in strategies_list if s.id and s.id != "s0"]
            if not strategies_to_use:
                strategies_to_use = strategies_list[:3]
            last_ti = visual_list[-1].transcript_index if visual_list else 0
            last_speaker = visual_list[-1].speaker if visual_list else "Speaker_0"
            idx = 0
            while len(visual_list) < 3 and strategies_to_use:
                s = strategies_to_use[idx % len(strategies_to_use)]
                idx += 1
                content_preview = (s.content or "").replace("\n", " ").strip()
                if len(content_preview) > 80:
                    content_preview = content_preview[:80] + "…"
                image_prompt = f"宫崎骏吉卜力动画风格，温暖自然色调。画面表现推荐策略「{s.title or s.label}」：{content_preview or '该策略的核心建议'}。左侧为用户采纳该策略时的自信姿态，右侧为对方反应。"
                visual_list.append(VisualData(
                    transcript_index=last_ti,
                    speaker=last_speaker,
                    image_prompt=image_prompt,
                    emotion="策略建议",
                    subtext="",
                    context=f"推荐策略: {s.title}",
                    my_inner="",
                    other_inner=""
                ))
                logger.info(f"补足 visual: 策略「{s.title}」-> 第 {len(visual_list)} 张")
        
        # 8. 后处理（可选）
        # TODO: 如果存在 scripts/postprocess.py，执行后处理
        
        execution_time_ms = int((time.time() - start_time) * 1000)
        
        logger.info(f"技能执行成功: {skill_id}")
        logger.info(f"  - 执行耗时: {execution_time_ms}ms")
        logger.info(f"  - 关键时刻数量: {len(visual_list)}")
        logger.info(f"  - 策略数量: {len(strategies_list)}")
        
        # 返回结果
        return {
            "skill_id": skill_id,
            "result": Call2Response(
                visual=visual_list,
                strategies=strategies_list
            ),
            "execution_time_ms": execution_time_ms,
            "success": True
        }
        
    except Exception as e:
        execution_time_ms = int((time.time() - start_time) * 1000) if 'start_time' in locals() else 0
        logger.error(f"技能执行失败: {skill_id}, 错误: {e}")
        return {
            "skill_id": skill_id,
            "result": None,
            "execution_time_ms": execution_time_ms,
            "success": False,
            "error_message": str(e)
        }
