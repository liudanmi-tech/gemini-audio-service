"""场景图片生成器：基于录音转录独立生成场景插图，与技能分析并行"""
import asyncio
import json
import logging
import re
import uuid as _uuid

import google.generativeai as genai

from database.connection import AsyncSessionLocal
from database.models import Session, StrategyAnalysis, Profile
from sqlalchemy import select

logger = logging.getLogger(__name__)


async def _analyze_character_profiles(
    transcript: list,
    gemini_flash_model: str,
) -> dict:
    """
    [场景1降级] 深度分析对话，为双方建立一致的视觉档案（性别/年龄段/角色/外貌描述）。
    无参考图时用于全部场景图片，确保多张图中人物形象一致。

    Returns:
        {
          "user":  {"gender": "男", "age_range": "25-35岁", "role": "职场员工", "appearance": "穿商务休闲装的年轻男性"},
          "other": {"gender": "男", "age_range": "40-50岁", "role": "领导/上司", "appearance": "穿正式西装的中年领导"},
          "consistency_header": "左侧为穿商务休闲装的年轻男性（用户），右侧为穿正式西装的中年领导（对方）。"
        }
    """
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


async def _extract_mentioned_people(
    transcript: list,
    gemini_flash_model: str,
) -> list:
    """
    [场景2] 从用户口述文本中提取所有提到的具体人物名称。

    Returns:
        ["张经理", "李总监", ...]  若无则返回 []
    """
    narration = "\n".join([t.get("text", "") for t in transcript if t.get("text")])
    if not narration.strip():
        return []

    prompt = (
        "分析以下用户的口述内容，提取所有提到的具体人名或称呼。\n\n"
        f"口述内容：\n{narration[:3000]}\n\n"
        "规则：\n"
        "- 提取具体人名或称呼（如：张经理、李总监、小王、老板）\n"
        "- 排除泛指（如：大家、同事们、他们、我）\n"
        "- 只返回JSON数组，格式：[\"张经理\", \"李总监\"]，若无则返回 []"
    )
    try:
        model = genai.GenerativeModel(gemini_flash_model)
        response = await asyncio.to_thread(model.generate_content, prompt)
        text = response.text.strip()
        m = re.search(r'\[.*?\]', text, re.DOTALL)
        if m:
            people = json.loads(m.group())
            result = [p for p in people if isinstance(p, str) and p.strip()]
            logger.info(f"[场景2] 提取到人物: {result}")
            return result
    except Exception as e:
        logger.warning(f"[场景2] 提取人物失败: {e}")
    return []


async def _infer_person_appearance(
    person_name: str,
    narration_text: str,
    gemini_flash_model: str,
) -> str:
    """
    [场景2降级] 无档案照片时，从口述内容推断某人的外貌特征，
    用于构建 consistency_header 注入 prompt，保障多图一致性。

    Returns:
        一句话外貌描述，如 "穿正式西装的中年男性领导"
    """
    prompt = (
        f"从以下口述内容中，推断「{person_name}」的外貌或形象特征。\n\n"
        f"口述内容：\n{narration_text[:2000]}\n\n"
        "若口述中有相关描述（职位、年龄、性别、衣着等），请据此推断其外貌。\n"
        "只返回一句话外貌描述，如：穿正式西装的中年男性领导\n"
        "若完全无法推断，返回：职场人物"
    )
    try:
        model = genai.GenerativeModel(gemini_flash_model)
        response = await asyncio.to_thread(model.generate_content, prompt)
        appearance = response.text.strip().strip("「」\"'")
        logger.info(f"[场景2降级] {person_name} 外貌推断: {appearance}")
        return appearance
    except Exception as e:
        logger.warning(f"[场景2降级] 外貌推断失败 {person_name}: {e}")
        return "职场人物"


async def generate_scene_images(
    transcript: list,           # 已解析的对话列表
    style_key: str,
    session_id: str,
    user_id: str,
    gemini_flash_model: str,    # 传入 GEMINI_FLASH_MODEL 常量
    generate_image_fn,          # 传入 generate_image_from_prompt 函数（sync）
    get_profile_refs_fn=None,   # 场景1：传入 _get_profile_reference_images（async）
    speaker_mapping: dict = None,       # {Speaker_0: profile_id, ...}，用于场景类型判断
    fetch_profile_image_fn=None,        # 场景2：传入 _fetch_profile_image_from_oss（sync）
):
    """
    分析录音场景并并行生成图片，保存到 strategy_analysis.scene_images。

    支持两种场景类型（自动检测）：
      场景1：多人对话 或 单人但声纹匹配非用户自己 → 声纹映射档案照片
      场景2：单人 且 声纹匹配是用户自己           → 文本提取人物 + 档案照片/降级推断
    """
    async with AsyncSessionLocal() as db:
        try:
            # ── 1. 更新 image_status = generating ──────────────────────────
            sess = await db.get(Session, _uuid.UUID(session_id))
            if sess:
                sess.image_status = "generating"
                await db.commit()

            # ── 2. 检测场景类型 ─────────────────────────────────────────────
            # 规则：
            #   speaker_count > 1                             → 场景1
            #   speaker_count == 1 且说话人声纹 ≠ 用户自己   → 场景1
            #   speaker_count == 1 且说话人声纹 = 用户自己   → 场景2（事后自述）
            speakers = list(set([t.get("speaker") for t in transcript if t.get("speaker")]))
            speaker_count = len(speakers)

            is_narration_mode = False
            if speaker_count == 1 and speaker_mapping:
                single_speaker = speakers[0]
                mapped_pid = speaker_mapping.get(single_speaker)
                if mapped_pid:
                    try:
                        p = await db.get(Profile, _uuid.UUID(str(mapped_pid)))
                        if p and p.relationship_type in ("自己", "Self", "self"):
                            is_narration_mode = True
                            logger.info(
                                f"[场景生图] ✅ 场景2（事后自述）: "
                                f"speaker={single_speaker} profile={mapped_pid}"
                            )
                    except Exception as _e:
                        logger.warning(f"[场景生图] 场景类型检测异常: {_e}")

            if not is_narration_mode:
                logger.info(f"[场景生图] 场景1（多人/非自己）: speaker_count={speaker_count}")

            # ── 3. 构建对话文本用于场景提取 ─────────────────────────────────
            lines = []
            for t in (transcript if isinstance(transcript, list) else []):
                text = t.get("text", "")
                if not text:
                    continue
                if is_narration_mode:
                    lines.append(text)                          # 场景2：纯口述，不加角色标签
                else:
                    label = "[我]" if t.get("is_me") else "[对方]"
                    lines.append(f"{label} {text}")             # 场景1：带角色标签
            transcript_str = "\n".join(lines[:80])

            # ── 4. Gemini 提取场景列表 ──────────────────────────────────────
            if is_narration_mode:
                scene_prompt = f"""分析以下用户的事后口述，识别1-3个最有画面感的场景。

口述内容：
{transcript_str}

规则：
- 场景数量1-3个，不要重复，选最有代表性的
- 明确描述「用户」和涉及的具体人物（保留原称呼，如张经理）在做什么
- 描述示例："用户向张经理汇报预算情况，表情紧张"、"用户与李总监商量解决方案"
- 若场景仅涉及用户自身，可只描述用户
- 只返回JSON：{{"scene_count": 2, "scenes": ["场景1", "场景2"]}}"""
            else:
                scene_prompt = f"""分析以下录音对话，识别1-3个最有画面感的场景。

对话角色说明：
- [我] = 用户，画面中固定在左侧
- [对方] = 对话另一方，画面中固定在右侧

对话内容：
{transcript_str}

规则：
- 场景数量1-3个，选最有代表性的，不要重复相似场景
- 每个场景必须明确说明【谁】在做【什么动作】，使用"用户"和"对方"指代（不要用Speaker_0/1）
- 必须符合对话实际逻辑：如果是用户在向对方汇报，就写"用户正在向对方汇报"，不能颠倒
- 描述格式示例："用户正在向对方汇报工作进展，表情认真"、"对方向用户提出质疑，用户在解释"
- 只返回JSON：{{"scene_count": 2, "scenes": ["场景1", "场景2"]}}"""

            model = genai.GenerativeModel(gemini_flash_model)
            response = await asyncio.to_thread(model.generate_content, scene_prompt)
            text = response.text.strip()
            json_match = re.search(r'\{.*\}', text, re.DOTALL)
            scenes_data = json.loads(json_match.group()) if json_match else {}
            scenes = scenes_data.get("scenes", [])[:3]

            if not scenes:
                logger.warning(f"[场景生图] 未提取到场景, session={session_id}")
                scenes = ["用户与对方正在进行面对面交流"]

            logger.info(f"[场景生图] 提取到 {len(scenes)} 个场景: {scenes}")

            # ── 5. 准备参考图数据（按场景类型分路）─────────────────────────
            # 场景1 变量
            profile_refs = []
            consistency_header = ""
            # 场景2 变量
            # people_refs: {person_name: {"photo": (bytes, mime) or None, "appearance": str or None}}
            people_refs = {}
            user_photo = None   # 用户自己的档案照片（场景2用）

            if is_narration_mode:
                # ── 场景2：提取提到的人物 → 档案照片 / 降级外貌推断 ──────
                narration_text = "\n".join([t.get("text", "") for t in transcript if t.get("text")])
                mentioned_people = await _extract_mentioned_people(transcript, gemini_flash_model)

                for person_name in mentioned_people:
                    # 模糊匹配档案 name 字段
                    q = await db.execute(
                        select(Profile).where(
                            Profile.user_id == _uuid.UUID(user_id),
                            Profile.name.ilike(f"%{person_name}%")
                        ).limit(1)
                    )
                    profile = q.scalar_one_or_none()
                    photo = None
                    if profile and fetch_profile_image_fn:
                        photo = await asyncio.to_thread(
                            fetch_profile_image_fn, user_id, str(profile.id)
                        )

                    if photo:
                        people_refs[person_name] = {"photo": photo, "appearance": None}
                        logger.info(f"[场景2] 档案匹配成功: {person_name} → {profile.id}")
                    else:
                        # 智能降级：推断外貌，后续注入场景 prompt
                        appearance = await _infer_person_appearance(
                            person_name, narration_text, gemini_flash_model
                        )
                        people_refs[person_name] = {"photo": None, "appearance": appearance}
                        logger.info(f"[场景2] 无档案照片，降级: {person_name} → {appearance}")

                # 加载用户自己的档案照片（作为"左侧人物"参考）
                if speakers and speaker_mapping and fetch_profile_image_fn:
                    self_pid = speaker_mapping.get(speakers[0])
                    if self_pid:
                        user_photo = await asyncio.to_thread(
                            fetch_profile_image_fn, user_id, str(self_pid)
                        )
                        if user_photo:
                            logger.info(f"[场景2] 已加载用户自己的档案照片")

            else:
                # ── 场景1：声纹映射档案照片 + 降级人物分析 ─────────────────
                if get_profile_refs_fn:
                    try:
                        profile_refs = await get_profile_refs_fn(session_id, user_id, db)
                        logger.info(f"[场景生图] 已加载 {len(profile_refs)} 张档案参考图")
                    except Exception as _pe:
                        logger.warning(f"[场景生图] 档案参考图加载失败: {_pe}")

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

            # ── 6. 并行生成所有图片 ─────────────────────────────────────────
            async def gen_one(i, scene):
                if is_narration_mode:
                    # 场景2：逐场景动态拼装参考图和一致性描述
                    ref_images = []
                    desc_parts = []

                    # 左侧：用户自己的档案照片（如有）
                    if user_photo:
                        ref_images.append(user_photo)

                    # 右侧：场景中提到的人物
                    for person_name, ref_data in people_refs.items():
                        if person_name in scene:
                            if ref_data["photo"]:
                                ref_images.append(ref_data["photo"])
                            elif ref_data["appearance"]:
                                # 无照片时注入外貌描述保持一致性
                                desc_parts.append(f"对方为{ref_data['appearance']}")

                    # 将降级外貌描述拼接到场景文本最前
                    if desc_parts:
                        scene_with_profile = "，".join(desc_parts) + "。" + scene
                    else:
                        scene_with_profile = scene

                    ref = ref_images if ref_images else None

                else:
                    # 场景1：统一参考图 + 一致性头部（无照片时降级）
                    if not profile_refs and consistency_header:
                        scene_with_profile = f"{consistency_header}{scene}"
                    else:
                        scene_with_profile = scene
                    ref = profile_refs if profile_refs else None

                # generate_image_fn 是同步函数，通过 asyncio.to_thread 调用
                # 每张图最多等 120 秒，超时返回 None（视为失败）
                try:
                    return await asyncio.wait_for(
                        asyncio.to_thread(
                            generate_image_fn,
                            scene_with_profile,
                            user_id, session_id, 1000 + i,  # index 1000+ 避免与技能图片冲突
                            ref, 3, style_key
                        ),
                        timeout=360.0,
                    )
                except asyncio.TimeoutError:
                    logger.error(f"[场景生图] 图{i} 生成超时(360s)，跳过")
                    return None

            results = await asyncio.gather(
                *[gen_one(i, scene) for i, scene in enumerate(scenes)],
                return_exceptions=True
            )

            # ── 7. 组装 scene_images ────────────────────────────────────────
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

            # ── 8. 保存到 strategy_analysis（upsert）──────────────────────
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
                        logger.info(f"[场景生图] 兜底重试成功，scene_images 已写入, session={session_id}")
                        break
                else:
                    logger.warning(f"[场景生图] 兜底重试超时，strategy_analysis 未出现, session={session_id}")

            # ── 9. 更新 image_status = completed ───────────────────────────
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
