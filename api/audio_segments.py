"""
音频片段提取API路由
"""
import io
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
    result = await db.execute(
        select(Session).where(
            Session.id == uuid.UUID(session_id),
            Session.user_id == uuid.UUID(user_id)
        )
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="对话不存在")
    if not session.audio_url and not session.audio_path:
        raise HTTPException(
            status_code=400,
            detail="原音频未持久化，无法剪切片段；请确保录音分析已完成且服务已配置原音频存储。"
        )
    local_path, is_temp = get_session_audio_local_path(session.audio_url, session.audio_path)
    if not local_path:
        raise HTTPException(status_code=502, detail="无法获取原音频文件")
    try:
        ext = Path(local_path).suffix or ".m4a"
        segment_bytes = cut_audio_segment(local_path, request.start_time, request.end_time)
    except Exception as e:
        logger.exception("剪切音频失败: %s", e)
        err_msg = str(e).lower()
        if "ffprobe" in err_msg or "avprobe" in err_msg or "ffmpeg" in err_msg or "couldn't find" in err_msg:
            detail = "服务器未安装 ffmpeg，无法剪切音频。请在服务器上执行: sudo apt install -y ffmpeg"
        else:
            detail = f"剪切音频失败: {str(e)}"
        raise HTTPException(status_code=500, detail=detail)
    finally:
        if is_temp and local_path and os.path.isfile(local_path):
            try:
                os.unlink(local_path)
            except Exception:
                pass
    segment_id = f"{session_id}_{int(request.start_time)}_{int(request.end_time)}"
    audio_url = upload_segment_bytes(segment_bytes, user_id, session_id, segment_id, ext)
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
