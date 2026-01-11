"""
FastAPI 任务管理 API
扩展 main.py，添加任务管理相关接口
"""

import os
import json
import uuid
import time
from datetime import datetime, timedelta
from typing import List, Optional
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from pydantic import BaseModel
from dotenv import load_dotenv

# 导入主模块的分析功能
from main import (
    app,
    analyze_audio,
    AudioAnalysisResponse,
    DialogueItem,
    wait_for_file_active,
    parse_gemini_response,
    logger,
    genai
)

# 加载环境变量
load_dotenv()

# ==================== 数据模型 ====================

class TaskItem(BaseModel):
    """任务项数据模型"""
    session_id: str
    title: str
    start_time: str  # ISO8601 格式
    end_time: Optional[str] = None
    duration: int  # 秒
    tags: List[str] = []
    status: str  # recording|analyzing|archived|burned
    emotion_score: Optional[int] = None
    speaker_count: Optional[int] = None

class TaskListResponse(BaseModel):
    """任务列表响应"""
    sessions: List[TaskItem]
    pagination: dict

class TaskDetailResponse(BaseModel):
    """任务详情响应"""
    session_id: str
    title: str
    start_time: str
    end_time: Optional[str] = None
    duration: int
    tags: List[str] = []
    status: str
    emotion_score: Optional[int] = None
    speaker_count: Optional[int] = None
    dialogues: List[dict] = []
    risks: List[str] = []
    created_at: str
    updated_at: str

class UploadResponse(BaseModel):
    """上传响应"""
    session_id: str
    audio_id: str
    title: str
    status: str
    estimated_duration: Optional[int] = None
    created_at: str

class APIResponse(BaseModel):
    """通用 API 响应"""
    code: int
    message: str
    data: Optional[dict] = None
    timestamp: Optional[str] = None

# ==================== 内存存储（临时，后续改为数据库） ====================

# 任务存储（session_id -> task_data）
tasks_storage: dict = {}

# 分析结果存储（session_id -> analysis_result）
analysis_storage: dict = {}

# ==================== API 接口 ====================

@app.post("/api/v1/audio/upload")
async def upload_audio_api(
    file: UploadFile = File(...),
    title: Optional[str] = None
):
    """
    上传音频文件并开始分析
    
    Args:
        file: 音频文件
        title: 任务标题（可选）
        
    Returns:
        上传响应，包含 session_id
    """
    try:
        # 生成 session_id
        session_id = str(uuid.uuid4())
        
        # 如果没有提供标题，使用时间戳
        if not title:
            formatter = datetime.now().strftime("%H:%M")
            title = f"录音 {formatter}"
        
        # 创建任务记录（状态：analyzing）
        start_time = datetime.now()
        task_data = {
            "session_id": session_id,
            "title": title,
            "start_time": start_time.isoformat(),
            "end_time": None,
            "duration": 0,  # 稍后更新
            "tags": [],
            "status": "analyzing",
            "emotion_score": None,
            "speaker_count": None,
            "created_at": start_time.isoformat(),
            "updated_at": start_time.isoformat()
        }
        
        tasks_storage[session_id] = task_data
        
        # 异步调用分析（在实际项目中应该使用 Celery）
        import asyncio
        asyncio.create_task(analyze_audio_async(session_id, file, task_data))
        
        # 返回响应
        return APIResponse(
            code=200,
            message="上传成功",
            data={
                "session_id": session_id,
                "audio_id": session_id,  # 简化处理
                "title": title,
                "status": "analyzing",
                "estimated_duration": 300,
                "created_at": start_time.isoformat()
            },
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"上传音频失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


async def analyze_audio_async(session_id: str, file: UploadFile, task_data: dict):
    """
    异步分析音频文件
    
    Args:
        session_id: 任务ID
        file: 音频文件
        task_data: 任务数据
    """
    try:
        # 调用主模块的分析功能
        result = await analyze_audio(file)
        
        # 计算情绪分数（简化版）
        emotion_score = calculate_emotion_score(result)
        
        # 生成标签
        tags = generate_tags(result)
        
        # 更新任务数据
        end_time = datetime.now()
        duration = int((end_time - datetime.fromisoformat(task_data["start_time"])).total_seconds())
        
        task_data.update({
            "end_time": end_time.isoformat(),
            "duration": duration,
            "status": "archived",
            "emotion_score": emotion_score,
            "speaker_count": result.speaker_count,
            "tags": tags,
            "updated_at": end_time.isoformat()
        })
        
        # 保存分析结果
        analysis_storage[session_id] = {
            "dialogues": [d.dict() for d in result.dialogues],
            "risks": result.risks
        }
        
        logger.info(f"任务 {session_id} 分析完成")
        
    except Exception as e:
        logger.error(f"分析音频失败: {e}")
        task_data["status"] = "failed"
        task_data["updated_at"] = datetime.now().isoformat()


def calculate_emotion_score(result: AudioAnalysisResponse) -> int:
    """计算情绪分数（简化版）"""
    score = 70  # 基础分数
    
    for dialogue in result.dialogues:
        tone = dialogue.tone.lower()
        if tone in ["愤怒", "焦虑", "紧张", "angry", "anxious", "tense"]:
            score -= 20
        elif tone in ["轻松", "平静", "relaxed", "calm"]:
            score += 5
    
    # 风险点降低分数
    score -= len(result.risks) * 10
    
    return max(0, min(100, score))


def generate_tags(result: AudioAnalysisResponse) -> List[str]:
    """生成标签"""
    tags = []
    
    # 根据风险点生成标签
    for risk in result.risks:
        if "PUA" in risk or "pua" in risk.lower():
            tags.append("#PUA预警")
        if "预算" in risk or "budget" in risk.lower():
            tags.append("#预算")
        if "争议" in risk or "dispute" in risk.lower():
            tags.append("#争议")
    
    # 根据语气生成标签
    tones = [d.tone for d in result.dialogues]
    if any("愤怒" in t or "angry" in t.lower() for t in tones):
        tags.append("#急躁")
    if any("画饼" in t or "promise" in t.lower() for t in tones):
        tags.append("#画饼")
    
    return tags if tags else ["#正常"]


@app.get("/api/v1/tasks/sessions")
async def get_task_list(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    date: Optional[str] = None,
    status: Optional[str] = None
):
    """
    获取任务列表
    
    Args:
        page: 页码
        page_size: 每页数量
        date: 日期筛选（YYYY-MM-DD）
        status: 状态筛选
        
    Returns:
        任务列表
    """
    try:
        # 获取所有任务
        all_tasks = list(tasks_storage.values())
        
        # 筛选
        filtered_tasks = all_tasks
        
        if date:
            # 按日期筛选
            target_date = datetime.fromisoformat(date).date()
            filtered_tasks = [
                t for t in filtered_tasks
                if datetime.fromisoformat(t["start_time"]).date() == target_date
            ]
        
        if status:
            # 按状态筛选
            filtered_tasks = [t for t in filtered_tasks if t["status"] == status]
        
        # 排序（按创建时间倒序）
        filtered_tasks.sort(key=lambda x: x["created_at"], reverse=True)
        
        # 分页
        total = len(filtered_tasks)
        start = (page - 1) * page_size
        end = start + page_size
        paginated_tasks = filtered_tasks[start:end]
        
        # 转换为响应格式
        task_items = [
            TaskItem(
                session_id=t["session_id"],
                title=t["title"],
                start_time=t["start_time"],
                end_time=t.get("end_time"),
                duration=t["duration"],
                tags=t["tags"],
                status=t["status"],
                emotion_score=t.get("emotion_score"),
                speaker_count=t.get("speaker_count")
            )
            for t in paginated_tasks
        ]
        
        return APIResponse(
            code=200,
            message="success",
            data={
                "sessions": [t.dict() for t in task_items],
                "pagination": {
                    "page": page,
                    "page_size": page_size,
                    "total": total,
                    "total_pages": (total + page_size - 1) // page_size
                }
            },
            timestamp=datetime.now().isoformat()
        )
        
    except Exception as e:
        logger.error(f"获取任务列表失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取列表失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}")
async def get_task_detail(session_id: str):
    """
    获取任务详情
    
    Args:
        session_id: 任务ID
        
    Returns:
        任务详情
    """
    try:
        # 获取任务数据
        task_data = tasks_storage.get(session_id)
        if not task_data:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        # 获取分析结果
        analysis_result = analysis_storage.get(session_id, {})
        
        # 构建响应
        detail = TaskDetailResponse(
            session_id=task_data["session_id"],
            title=task_data["title"],
            start_time=task_data["start_time"],
            end_time=task_data.get("end_time"),
            duration=task_data["duration"],
            tags=task_data["tags"],
            status=task_data["status"],
            emotion_score=task_data.get("emotion_score"),
            speaker_count=task_data.get("speaker_count"),
            dialogues=analysis_result.get("dialogues", []),
            risks=analysis_result.get("risks", []),
            created_at=task_data["created_at"],
            updated_at=task_data["updated_at"]
        )
        
        return APIResponse(
            code=200,
            message="success",
            data=detail.dict(),
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务详情失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取详情失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}/status")
async def get_task_status(session_id: str):
    """
    查询任务分析状态
    
    Args:
        session_id: 任务ID
        
    Returns:
        任务状态
    """
    try:
        task_data = tasks_storage.get(session_id)
        if not task_data:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        return APIResponse(
            code=200,
            message="success",
            data={
                "session_id": session_id,
                "status": task_data["status"],
                "progress": 1.0 if task_data["status"] == "archived" else 0.5,
                "estimated_time_remaining": 0 if task_data["status"] == "archived" else 30,
                "updated_at": task_data["updated_at"]
            },
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取状态失败: {str(e)}")


@app.get("/api/v1/health")
async def health_check():
    """健康检查接口"""
    return {"message": "音频分析服务正在运行", "status": "ok"}


