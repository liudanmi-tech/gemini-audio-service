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


async def _analyze_character_profiles(
    transcript: list,
    gemini_flash_model: str,
) -> dict:
    """
    深度分析对话，为双方建立一致的视觉档案（性别/年龄段/角色/外貌描述）。
    无参考图时用于全部场景图片，确保多张图中人物形象一致。

    Returns:
        {
          "user":  {"gender": "男", "age_range": "25-35岁", "role": "职场员工", "appearance": "穿商务休闲装的年轻男性"},
          "other": {"gender": "男", "age_range": "40-50岁", "role": "领导/上司", "appearance": "穿正式西装的中年领导"},
          "consistency_header": "左侧为穿商务休闲装的年轻男性（用户），右侧为穿正式西装的中年领导（对方）。"
        }
    """
    # 分别收集 我 / 对方 的话语样本
    user_lines, other_lines = [], []
    for t in transcript:
        text = t.get("text", "").strip()
        if not text:
            continue
        if t.get("is_me"):
            user_lines.append(text)
        else:
            other_lines.append(text)

    user_sample  = "\n".join(user_lines[:20])
    other_sample = "\n".join(other_lines[:20])

    prompt = (
        "请根据以下对话内容，推断两位说话者的形象特征。\n\n"
        f"【用户（我）说的话】：\n{user_sample or '（无）'}\n\n"
        f"【对方说的话】：\n{other_sample or '（无）'}\n\n"
        "请综合以下信息判断：称呼方式、说话语气、词汇习惯、提及的角色关系等。\n"
        "只返回 JSON，格式如下（不要解释）：\n"
        "{\n"
        "  \"user\": {\"gender\": \"男或女\", \"age_range\": \"如20-30岁\", \"role\": \"如职场员工\", \"appearance\": \"一句话外貌，如穿商务休闲装的年轻男性\"},\n"
        "  \"other\": {\"gender\": \"男或女\", \"age_range\": \"如40-50岁\", \"role\": \"如领导/上司\", \"appearance\": \"一句话外貌，如穿正式西装的中年男性领导\"}\n"
        "}"
    )
    try:
        model = genai.GenerativeModel(gemini_flash_model)
        response = await asyncio.to_thread(model.generate_content, prompt)
        raw = response.text.strip()
        m = re.search(r'\{.*\}', raw, re.DOTALL)
        if m:
            data = json.loads(m.group())
            user_app  = data.get("user", {}).get("appearance", "")
            other_app = data.get("other", {}).get("appearance", "")

            # 构建一致性头部：注入全部场景的 prompt 最前面
            parts = []
            if user_app:
                parts.append(f"左侧为{user_app}（用户）")
            if other_app:
                parts.append(f"右侧为{other_app}（对方）")
            header = "，".join(parts) + "。" if parts else ""

            data["consistency_header"] = header
            logger.info(f"[场景生图] 人物档案: user={user_app} | other={other_app}")
            logger.info(f"[场景生图] 一致性头部: {header}")
            return data
    except Exception as e:
        logger.warning(f"[场景生图] 人物档案分析失败: {e}")
    return {"consistency_header": ""}


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

            # 2. 构建带角色标签的对话文本，供场景分析使用
            lines = []
            for t in (transcript if isinstance(transcript, list) else []):
                speaker = t.get("speaker", "")
                text = t.get("text", "")
                is_me = t.get("is_me", False)
                if text:
                    label = "[我]" if is_me else "[对方]"
                    lines.append(f"{label} {text}")
            transcript_str = "\n".join(lines[:80])  # 最多80行避免超长

            # 3. 调用 Gemini Flash 分析场景（含角色标签，要求明确动作主体）
            scene_prompt = f"""分析以下录音对话，识别1-5个最有画面感的场景。

对话角色说明：
- [我] = 用户，画面中固定在左侧
- [对方] = 对话另一方，画面中固定在右侧

对话内容：
{transcript_str}

规则：
- 场景数量1-5个（对话越长可提取越多，但不要重复相似场景）
- 每个场景必须明确说明【谁】在做【什么动作】，使用"用户"和"对方"指代（不要用Speaker_0/1）
- 必须符合对话实际逻辑：如果是用户在向对方汇报，就写"用户正在向对方汇报"，不能颠倒
- 描述格式示例："用户正在向对方汇报工作进展，表情认真"、"对方向用户提出质疑，用户在解释"
- 只返回JSON：{{"scene_count": 2, "scenes": ["场景1", "场景2"]}}"""

            model = genai.GenerativeModel(gemini_flash_model)
            response = await asyncio.to_thread(model.generate_content, scene_prompt)
            text = response.text.strip()

            # 解析 JSON
            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            scenes_data = json.loads(json_match.group()) if json_match else {}
            scenes = scenes_data.get("scenes", [])[:5]

            if not scenes:
                logger.warning(f"[场景生图] 未提取到场景, session={session_id}")
                scenes = ["用户与对方正在进行面对面交流"]  # 兜底

            logger.info(f"[场景生图] 提取到 {len(scenes)} 个场景: {scenes}")

            # 4. 加载档案参考图（用于人物一致性）
            profile_refs = []
            if get_profile_refs_fn:
                try:
                    profile_refs = await get_profile_refs_fn(session_id, user_id, db)
                    logger.info(f"[场景生图] 已加载 {len(profile_refs)} 张档案参考图")
                except Exception as _pe:
                    logger.warning(f"[场景生图] 档案参考图加载失败: {_pe}")

            # 4.5. 无档案参考图时：深度分析人物形象，建立全局一致性描述
            consistency_header = ""
            if not profile_refs:
                logger.info(f"[场景生图] 无档案参考图，启动人物档案分析...")
                try:
                    char_profiles = await asyncio.wait_for(
                        _analyze_character_profiles(transcript, gemini_flash_model),
                        timeout=30.0,
                    )
                except asyncio.TimeoutError:
                    logger.warning(f"[场景生图] 人物档案分析超时(30s)，跳过，直接生成")
                    char_profiles = {"consistency_header": ""}
                consistency_header = char_profiles.get("consistency_header", "")
                if consistency_header:
                    logger.info(f"[场景生图] 人物一致性头部已就绪，将注入所有场景 prompt")
                else:
                    logger.info(f"[场景生图] 无法建立人物档案，使用原始场景描述")

            # 5. 并行生成所有图片
            async def gen_one(i, scene):
                # 有档案参考图：正常传入参考图（图片级别的人物一致性）
                # 无档案参考图：将人物档案描述拼入场景描述开头（文本级别的人物一致性）
                if not profile_refs and consistency_header:
                    # 确保人物位置描述在最前，场景描述在后
                    scene_with_profile = f"{consistency_header}{scene}"
                else:
                    scene_with_profile = scene

                # generate_image_fn is sync (old SDK), call via asyncio.to_thread
                # 每张图最多等 120 秒，超时返回 None（视为失败）
                try:
                    return await asyncio.wait_for(
                        asyncio.to_thread(
                            generate_image_fn,
                            scene_with_profile,
                            user_id, session_id, 1000 + i,  # index 1000+ 避免与技能图片冲突
                            profile_refs if profile_refs else None, 3, style_key
                        ),
                        timeout=120.0,
                    )
                except asyncio.TimeoutError:
                    logger.error(f"[场景生图] 图{i} 生成超时(120s)，跳过")
                    return None

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
