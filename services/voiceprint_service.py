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
    占位：不调用阿里云；按 speaker_label 映射到不同档案（Speaker_0->第1个，Speaker_1->第2个…），
    无标签则退回第1个档案；无档案则 (None, 0)。后续可接入阿里云 Speaker Verification 的 1:N 识别。
    """
    if not profile_ids:
        return (None, 0.0)
    # 占位：按说话人标签轮询到不同档案，便于多说话人显示不同名字
    if speaker_label and profile_ids:
        idx = 0
        if speaker_label.startswith("Speaker_"):
            try:
                idx = int(speaker_label.replace("Speaker_", "").strip()) % len(profile_ids)
            except ValueError:
                idx = hash(speaker_label) % len(profile_ids)
        else:
            idx = hash(speaker_label) % len(profile_ids) if speaker_label else 0
        matched = profile_ids[idx]
    else:
        matched = profile_ids[0]
    confidence = 0.8
    logger.info(f"声纹识别占位: speaker={speaker_label} segment=... -> profile_id={matched} confidence={confidence}")
    return (matched, confidence)
