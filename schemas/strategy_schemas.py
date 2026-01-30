"""
Call #2 策略分析相关数据模型与解析函数
供 main 与 skills 模块共用，避免循环导入
"""
import json
from typing import List, Optional
from pydantic import BaseModel
from fastapi import HTTPException


class StrategyItem(BaseModel):
    """策略项数据模型"""
    id: str  # 策略ID
    label: str  # 策略标签
    emoji: str  # 表情符号
    title: str  # 策略标题
    content: str  # 策略内容（Markdown格式）


class VisualData(BaseModel):
    """视觉数据模型"""
    transcript_index: int  # 关联的 transcript 索引
    speaker: str  # 说话人标识
    image_prompt: str  # 火柴人图片描述词（详细版）
    emotion: str  # 说话人情绪
    subtext: str  # 潜台词
    context: str  # 当时的情景或心理状态
    my_inner: str  # 我的内心OS
    other_inner: str  # 对方的内心OS
    image_url: Optional[str] = None  # 图片 URL（优先使用）
    image_base64: Optional[str] = None  # Base64 编码的图片数据（向后兼容，OSS 失败时使用）


class Call2Response(BaseModel):
    """Call #2 策略分析响应"""
    visual: List[VisualData]  # 视觉数据数组（关键时刻）
    strategies: List[StrategyItem]  # 策略列表


def parse_gemini_response(response_text: str) -> dict:
    """
    解析 Gemini 返回的文本，提取 JSON 数据

    Args:
        response_text: Gemini 返回的文本

    Returns:
        解析后的字典数据
    """
    text = response_text.strip()

    if "```json" in text:
        start = text.find("```json") + 7
        end = text.find("```", start)
        if end != -1:
            text = text[start:end].strip()
    elif "```" in text:
        start = text.find("```") + 3
        end = text.find("```", start)
        if end != -1:
            text = text[start:end].strip()

    try:
        data = json.loads(text)
        return data
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=500, detail=f"无法解析 Gemini 返回的 JSON: {str(e)}")
