"""场景图片生成器：基于录音转录独立生成场景插图，与技能分析并行"""
import asyncio
import json
import logging
import re
import uuid as _uuid

import google.generativeai as genai

from database.connection import AsyncSessionLocal
from database.models import Session, StrategyAnalysis
from sqlalchemy import select

logger = logging.getLogger(__name__)


async def _detect_speaker_genders(transcript_str: str, gemini_flash_model: str) -> str:
    """
    分析对话文本，判断各说话人性别，返回可直接拼入 prompt 的性别提示字符串。
    例："左侧人物为男性，右侧人物为女性。"
    失败或无法判断时返回空字符串。
    """
    try:
        prompt = (
            "请分析以下对话，判断每位说话人最可能的性别（男/女/未知）。\n"
            "只返回 JSON，格式：{\"Speaker_0\": \"男\", \"Speaker_1\": \"女\"}\n\n"
            f"对话内容：\n{transcript_str[:1200]}"
        )
        model = genai.GenerativeModel(gemini_flash_model)
        response = await asyncio.to_thread(model.generate_content, prompt)
        raw = response.text.strip()
        m = re.search(r'\{.*\}', raw, re.DOTALL)
        if not m:
            return ""
        gender_data: dict = json.loads(m.group())
        speakers = list(gender_data.keys())

        def gender_zh(key):
            v = gender_data.get(key, "未知")
            if v == "男":
                return "男性"
            if v == "女":
                return "女性"
            return None

        if len(speakers) >= 2:
            lg = gender_zh(speakers[0])
            rg = gender_zh(speakers[1])
            parts = []
            if lg:
                parts.append(f"左侧人物为{lg}")
            if rg:
                parts.append(f"右侧人物为{rg}")
            hint = "，".join(parts) + "。" if parts else ""
        elif len(speakers) == 1:
            g = gender_zh(speakers[0])
            hint = f"画面中人物为{g}。" if g else ""
        else:
            hint = ""

        logger.info(f"[场景生图] 性别检测结果: {gender_data} -> hint='{hint}'")
        return hint
    except Exception as e:
        logger.warning(f"[场景生图] 性别检测失败: {e}")
        return ""


async def generate_scene_images(
    transcript: list,           # 已解析的对话列表
    style_key: str,
    session_id: str,
    user_id: str,
    gemini_flash_model: str,    # 传入 GEMINI_FLASH_MODEL 常量
    generate_image_fn,          # 传入 generate_image_from_prompt 函数
    get_profile_refs_fn=None,   # 传入 _get_profile_reference_images（async）
):
    """分析录音场景并并行生成图片，保存到 strategy_analysis.scene_images"""
    async with AsyncSessionLocal() as db:
        try:
            # 1. 更新 image_status = generating
            sess = await db.get(Session, _uuid.UUID(session_id))
            if sess:
                sess.image_status = "generating"
                await db.commit()

            # 2. 将 transcript list 转成纯文本
            lines = []
            for t in (transcript if isinstance(transcript, list) else []):
                speaker = t.get("speaker", "")
                text = t.get("text", "")
                if text:
                    lines.append(f"{speaker}: {text}")
            transcript_str = "\n".join(lines[:80])  # 最多80行避免超长

            # 3. 调用 Gemini Flash 分析场景
            prompt = f"""分析以下录音对话，识别其中1-5个最有画面感的场景（人物互动/环境/关键动作）。
每个场景用一句中文描述，适合生成插图。

规则：
- 场景数量1-5个（对话越长可提取越多）
- 只要有画面感的场景，不要重复相似场景
- 只返回JSON，格式：{{"scene_count": 2, "scenes": ["场景1", "场景2"]}}

对话内容：
{transcript_str}"""

            model = genai.GenerativeModel(gemini_flash_model)
            response = await asyncio.to_thread(model.generate_content, prompt)
            text = response.text.strip()

            # 解析 JSON
            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            scenes_data = json.loads(json_match.group()) if json_match else {}
            scenes = scenes_data.get("scenes", [])[:5]

            if not scenes:
                logger.warning(f"[场景生图] 未提取到场景, session={session_id}")
                scenes = ["两人在室内进行对话交流"]  # 兜底

            logger.info(f"[场景生图] 提取到 {len(scenes)} 个场景: {scenes}")

            # 4. 加载档案参考图（用于人物一致性）
            profile_refs = []
            if get_profile_refs_fn:
                try:
                    profile_refs = await get_profile_refs_fn(session_id, user_id, db)
                    logger.info(f"[场景生图] 已加载 {len(profile_refs)} 张档案参考图")
                except Exception as _pe:
                    logger.warning(f"[场景生图] 档案参考图加载失败: {_pe}")

            # 4.5. 无档案参考图时：分析说话人性别，生成性别提示注入 prompt
            gender_hint = ""
            if not profile_refs:
                logger.info(f"[场景生图] 无档案参考图，启动性别检测...")
                gender_hint = await _detect_speaker_genders(transcript_str, gemini_flash_model)
                if gender_hint:
                    logger.info(f"[场景生图] 将在 prompt 中注入性别提示: {gender_hint}")
                else:
                    logger.info(f"[场景生图] 无法确定性别，使用原始 prompt")

            # 5. 并行生成所有图片
            async def gen_one(i, scene):
                # 有档案参考图：正常传入参考图，原始场景描述
                # 无档案参考图：将性别提示拼入场景描述开头
                scene_prompt = scene
                if not profile_refs and gender_hint:
                    scene_prompt = gender_hint + scene

                # generate_image_fn is sync (old SDK), call via asyncio.to_thread
                return await asyncio.to_thread(
                    generate_image_fn,
                    scene_prompt, user_id, session_id, 1000 + i,  # index 1000+ 避免与技能图片冲突
                    profile_refs if profile_refs else None, 3, style_key
                )

            results = await asyncio.gather(
                *[gen_one(i, scene) for i, scene in enumerate(scenes)],
                return_exceptions=True
            )

            # 6. 组装 scene_images
            scene_images = []
            for i, (scene, img) in enumerate(zip(scenes, results)):
                if isinstance(img, Exception) or img is None:
                    logger.error(f"[场景生图] 图{i}失败: {img}")
                    scene_images.append({
                        "index": 1000 + i,
                        "scene_description": scene,
                        "image_url": None,
                        "image_base64": None,
                    })
                else:
                    is_url = img.startswith("http")
                    scene_images.append({
                        "index": 1000 + i,
                        "scene_description": scene,
                        "image_url": img if is_url else None,
                        "image_base64": img if not is_url else None,
                    })
                    logger.info(f"[场景生图] 图{i} ✅ {'url' if is_url else 'b64'}")

            # 7. 保存到 strategy_analysis（upsert）
            sa_q = await db.execute(
                select(StrategyAnalysis).where(StrategyAnalysis.session_id == _uuid.UUID(session_id))
            )
            sa = sa_q.scalar_one_or_none()
            if sa:
                sa.scene_images = scene_images
                await db.commit()
                logger.info(f"[场景生图] 已更新 scene_images, session={session_id}")
            else:
                # StrategyAnalysis 尚未创建（技能还在跑），暂存到 analysis_stage_detail
                sess2 = await db.get(Session, _uuid.UUID(session_id))
                if sess2:
                    detail = dict(sess2.analysis_stage_detail) if sess2.analysis_stage_detail else {}
                    detail["scene_images_pending"] = scene_images
                    sess2.analysis_stage_detail = detail
                    await db.commit()
                    logger.info(f"[场景生图] StrategyAnalysis未创建，暂存到analysis_stage_detail")

                # 兜底重试：等待技能分析完成，直接写入 strategy_analysis（最多等 5 分钟）
                for _retry in range(30):
                    await asyncio.sleep(10)
                    sa_retry_q = await db.execute(
                        select(StrategyAnalysis).where(StrategyAnalysis.session_id == _uuid.UUID(session_id))
                    )
                    sa_retry = sa_retry_q.scalar_one_or_none()
                    if sa_retry:
                        sa_retry.scene_images = scene_images
                        await db.commit()
                        logger.info(f"[场景生图] 兜底重试成功，scene_images 已写入 strategy_analysis, session={session_id}")
                        break
                else:
                    logger.warning(f"[场景生图] 兜底重试超时，strategy_analysis 未出现, session={session_id}")

            # 8. 更新 image_status = completed
            sess3 = await db.get(Session, _uuid.UUID(session_id))
            if sess3:
                sess3.image_status = "completed"
                await db.commit()

        except Exception as e:
            logger.error(f"[场景生图] 异常: {e}", exc_info=True)
            try:
                async with AsyncSessionLocal() as db_err:
                    sess_err = await db_err.get(Session, _uuid.UUID(session_id))
                    if sess_err:
                        sess_err.image_status = "failed"
                        await db_err.commit()
            except Exception:
                pass
