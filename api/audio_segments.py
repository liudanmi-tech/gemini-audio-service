"""
音频片段提取API路由
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from typing import List, Optional
import uuid

from database.connection import get_db
from database.models import Session, AnalysisResult
from auth.jwt_handler import get_current_user_id
from pydantic import BaseModel

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
    """提取指定时间段的音频片段"""
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
    
    # TODO: 实现音频提取逻辑
    # 1. 获取原始音频文件路径
    # 2. 使用pydub或ffmpeg提取指定时间段
    # 3. 保存音频片段到OSS或本地
    # 4. 返回音频URL
    
    # 临时返回（需要实现实际的音频提取）
    segment_id = f"{session_id}_{int(request.start_time)}_{int(request.end_time)}"
    audio_url = f"/audio/segments/{segment_id}.m4a"  # 临时URL，需要替换为实际提取的音频URL
    
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
