"""
音频片段提取API路由
"""
import asyncio
import logging
import os
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
import uuid

from database.connection import get_db
from database.models import Session, AnalysisResult
from auth.jwt_handler import get_current_user_id
from pydantic import BaseModel
from utils.audio_storage import get_session_audio_local_path, upload_segment_bytes, cut_audio_segment

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/tasks/sessions", tags=["audio-segments"])


# Pydantic模型
class AudioSegmentResponse(BaseModel):
    id: str
    session_id: str
    speaker: str
    start_time: float
    end_time: float
    duration: float
    content: str
    audio_url: Optional[str] = None


class AudioSegmentListResponse(BaseModel):
    segments: List[AudioSegmentResponse]


class ExtractSegmentRequest(BaseModel):
    start_time: float
    end_time: float
    speaker: str


class ExtractSegmentResponse(BaseModel):
    segment_id: str
    audio_url: str
    duration: float


@router.get("/{session_id}/audio-segments", response_model=AudioSegmentListResponse)
async def get_audio_segments(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取对话的所有音频片段"""
    # 验证session属于当前用户
    result = await db.execute(
        select(Session).where(
            Session.id == uuid.UUID(session_id),
            Session.user_id == uuid.UUID(user_id)
        )
    )
    session = result.scalar_one_or_none()
    
    if not session:
        raise HTTPException(status_code=404, detail="对话不存在")
    
    # 获取分析结果
    result = await db.execute(
        select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
    )
    analysis = result.scalar_one_or_none()
    
    if not analysis or not analysis.dialogues:
        return AudioSegmentListResponse(segments=[])
    
    # 从dialogues中提取音频片段
    segments = []
    dialogues = analysis.dialogues if isinstance(analysis.dialogues, list) else []
    
    for index, dialogue in enumerate(dialogues):
        # 解析时间戳
        timestamp = dialogue.get("timestamp", "00:00")
        start_time = parse_timestamp(timestamp)
        
        # 计算结束时间
        if index < len(dialogues) - 1:
            next_timestamp = dialogues[index + 1].get("timestamp", "00:00")
            end_time = parse_timestamp(next_timestamp)
        else:
            end_time = float(session.duration) if session.duration else start_time + 5.0
        
        duration = end_time - start_time
        
        segment = AudioSegmentResponse(
            id=f"{session_id}_{index}",
            session_id=session_id,
            speaker=dialogue.get("speaker", "未知"),
            start_time=start_time,
            end_time=end_time,
            duration=duration,
            content=dialogue.get("content", ""),
            audio_url=None  # 需要调用extract-segment接口后才有URL
        )
        segments.append(segment)
    
    return AudioSegmentListResponse(segments=segments)


@router.post("/{session_id}/extract-segment", response_model=ExtractSegmentResponse)
async def extract_audio_segment(
    session_id: str,
    request: ExtractSegmentRequest,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """提取指定时间段的音频片段（依赖原音频已持久化）。"""
    import time
    import traceback
    t0 = time.time()
    local_path, is_temp = None, False
    logger.info("[extract-segment] ========== 开始 session=%s start=%.1f end=%.1f speaker=%s user=%s",
                session_id, request.start_time, request.end_time, request.speaker, user_id)
    try:
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id)
            )
        )
        session = result.scalar_one_or_none()
        if not session:
            logger.warning("[extract-segment] 404 对话不存在: session=%s", session_id)
            raise HTTPException(status_code=404, detail="对话不存在")
        logger.info("[extract-segment] 查询到 session: audio_url=%s audio_path=%s",
                    bool(session.audio_url), session.audio_path or "(none)")
        if not session.audio_url and not session.audio_path:
            raise HTTPException(
                status_code=400,
                detail="原音频未持久化，无法剪切片段；请确保录音分析已完成且服务已配置原音频存储。"
            )
        logger.info("[extract-segment] 开始获取原音频: %.2fs", time.time() - t0)
        local_path, is_temp = get_session_audio_local_path(session.audio_url, session.audio_path)
        logger.info("[extract-segment] 获取原音频完成: local_path=%s is_temp=%s %.2fs",
                    local_path[:50] + "..." if local_path and len(local_path) > 50 else local_path, is_temp, time.time() - t0)
        if not local_path:
            # 区分可能原因，便于用户/运维排查
            if session.audio_path:
                detail = "原音频本地文件不存在，可能已被清理。请重新上传该录音并分析。"
            elif session.audio_url:
                detail = "无法下载原音频文件，请检查网络或重新上传该录音。"
            else:
                detail = "无法获取原音频文件，请重新上传并分析该录音。"
            logger.warning("[extract-segment] 502 无法获取原音频: session=%s audio_url=%s audio_path=%s",
                           session_id, bool(session.audio_url), session.audio_path)
            raise HTTPException(status_code=502, detail=detail)
        ext = Path(local_path).suffix or ".m4a"
        logger.info("[extract-segment] 开始剪切: session=%s start=%.1f end=%.1f %.2fs",
                    session_id, request.start_time, request.end_time, time.time() - t0)
        # 在线程池执行，避免阻塞事件循环导致超时
        segment_bytes = await asyncio.to_thread(cut_audio_segment, local_path, request.start_time, request.end_time)
        logger.info("[extract-segment] 剪切完成: size=%d bytes %.2fs", len(segment_bytes), time.time() - t0)
    except HTTPException:
        raise
    except Exception as e:
        logger.exception("[extract-segment] 剪切音频失败: %s", e)
        err_msg = str(e).lower()
        if "ffprobe" in err_msg or "avprobe" in err_msg or "ffmpeg" in err_msg or "couldn't find" in err_msg:
            detail = "服务器未安装 ffmpeg，无法剪切音频。请在服务器上执行: sudo apt install -y ffmpeg"
        else:
            detail = f"剪切音频失败: {str(e)}"
        raise HTTPException(status_code=500, detail=detail)
    finally:
        if local_path and is_temp and os.path.isfile(local_path):
            try:
                os.unlink(local_path)
                logger.info("[extract-segment] 已删除临时文件: %s", local_path[:60])
            except Exception as ex:
                logger.warning("[extract-segment] 删除临时文件失败: %s", ex)
    segment_id = f"{session_id}_{int(request.start_time)}_{int(request.end_time)}"
    try:
        logger.info("[extract-segment] 开始上传: segment_id=%s size=%d %.2fs", segment_id, len(segment_bytes), time.time() - t0)
        audio_url = await asyncio.to_thread(upload_segment_bytes, segment_bytes, user_id, session_id, segment_id, ext)
        logger.info("[extract-segment] 上传完成: audio_url=%s %.2fs", bool(audio_url), time.time() - t0)
    except Exception as e:
        logger.exception("[extract-segment] 上传片段失败: %s", e)
        logger.error("[extract-segment] 上传失败堆栈:\n%s", traceback.format_exc())
        raise HTTPException(
            status_code=503,
            detail=f"片段上传失败，请稍后重试。({str(e)[:100]})"
        )
    logger.info("[extract-segment] ========== 成功 总耗时=%.2fs session=%s segment_id=%s", time.time() - t0, session_id, segment_id)
    return ExtractSegmentResponse(
        segment_id=segment_id,
        audio_url=audio_url,
        duration=request.end_time - request.start_time
    )


def parse_timestamp(timestamp: str) -> float:
    """解析时间戳（格式："MM:SS"）为秒数"""
    try:
        parts = timestamp.split(":")
        if len(parts) == 2:
            minutes = int(parts[0])
            seconds = float(parts[1])
            return minutes * 60 + seconds
    except:
        pass
    return 0.0
