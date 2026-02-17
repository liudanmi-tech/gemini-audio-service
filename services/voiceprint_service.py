"""
声纹服务：档案声纹注册、片段与档案匹配（占位实现，可后续接入阿里云 Speaker Verification）。
"""
import logging
from typing import Optional, Tuple, List

logger = logging.getLogger(__name__)


def register_voiceprint(
    profile_id: str,
    audio_url: Optional[str] = None,
    audio_path: Optional[str] = None,
) -> Optional[str]:
    """
    为档案注册声纹。输入：profile_id + 该档案的音频（URL 或本地路径）。
    占位：不调用阿里云，仅返回 mock voiceprint_id；后续可接入阿里云 Speaker Verification。
    """
    if not audio_url and not audio_path:
        logger.warning("register_voiceprint: 无音频输入")
        return None
    # 占位：返回 mock id
    voiceprint_id = f"mock_vp_{profile_id}"
    logger.info(f"声纹注册占位: profile_id={profile_id} -> voiceprint_id={voiceprint_id}")
    return voiceprint_id


def identify_speaker(
    segment_audio_path: str,
    user_id: str,
    profile_ids: List[str],
    speaker_label: Optional[str] = None,
) -> Tuple[Optional[str], float]:
    """
    将一段音频与当前用户的若干档案声纹比对，返回最佳匹配的 profile_id 与置信度。
    占位：不调用阿里云；按 speaker_label 映射到档案（Speaker_0->第1个，Speaker_1->第2个…）。
    重要：当说话人数量 > 档案数量时，超出部分的说话人视为「新人」，不映射，返回 (None, 0)，
    前端保持显示 Speaker_X，避免误将新人当作已有档案。
    后续可接入阿里云 Speaker Verification 的 1:N 识别。
    """
    if not profile_ids:
        return (None, 0.0)
    if not speaker_label:
        return (profile_ids[0], 0.8)
    # 占位：Speaker_0->档案0, Speaker_1->档案1, ... ；当 idx >= 档案数时为新人，不映射
    if speaker_label.startswith("Speaker_"):
        try:
            idx = int(speaker_label.replace("Speaker_", "").strip())
            if idx >= len(profile_ids):
                # 新人：录音中说话人数量 > 档案数量，该说话人无对应档案
                logger.info(f"声纹识别占位: speaker={speaker_label} 为新人（idx={idx} >= 档案数{len(profile_ids)}），不映射")
                return (None, 0.0)
            matched = profile_ids[idx]
        except ValueError:
            matched = profile_ids[0]
    else:
        idx = hash(speaker_label) % len(profile_ids) if speaker_label else 0
        matched = profile_ids[idx]
    confidence = 0.8
    logger.info(f"声纹识别占位: speaker={speaker_label} -> profile_id={matched} confidence={confidence}")
    return (matched, confidence)
