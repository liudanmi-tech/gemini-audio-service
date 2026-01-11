# 后端API更新方案

## 概述
根据产品需求文档，需要更新后端API以支持新的数据结构（Call #1和Call #2响应）。

## 已完成的工作
✅ 数据模型已添加（Call1Response, Call2Response等）
✅ 提示词已更新为新的格式

## 需要完成的工作

### 1. 更新 analyze_audio_from_path 函数的返回值处理

**位置**: `main.py` 第423-443行

**当前代码**:
```python
# 解析响应
analysis_data = parse_gemini_response(response.text)

# 解析对话列表
dialogues_list = []
if "dialogues" in analysis_data:
    for dialogue in analysis_data["dialogues"]:
        dialogues_list.append(DialogueItem(
            speaker=dialogue.get("speaker", "未知"),
            content=dialogue.get("content", ""),
            tone=dialogue.get("tone", "未知")
        ))

# 验证并构建返回数据
result = AudioAnalysisResponse(
    speaker_count=analysis_data.get("speaker_count", 0),
    dialogues=dialogues_list,
    risks=analysis_data.get("risks", [])
)

return result
```

**需要更新为**:
```python
# 解析响应
analysis_data = parse_gemini_response(response.text)

# 尝试解析新的Call1格式
try:
    # 解析转录列表
    transcript_list = []
    if "transcript" in analysis_data:
        for item in analysis_data["transcript"]:
            transcript_list.append(TranscriptItem(
                speaker=item.get("speaker", "未知"),
                text=item.get("text", ""),
                timestamp=item.get("timestamp"),
                is_me=item.get("is_me", False)
            ))
    
    # 构建Call1Response
    call1_result = Call1Response(
        mood_score=analysis_data.get("mood_score", 70),
        stats={
            "sigh": analysis_data.get("sigh_count", 0),
            "laugh": analysis_data.get("laugh_count", 0)
        },
        summary=analysis_data.get("summary", ""),
        transcript=transcript_list,
        risks=analysis_data.get("risks", [])
    )
    
    # 转换为旧格式以保持兼容性
    dialogues_list = []
    for item in transcript_list:
        dialogues_list.append(DialogueItem(
            speaker=item.speaker,
            content=item.text,
            tone="未知"  # 新格式不包含tone
        ))
    
    result = AudioAnalysisResponse(
        speaker_count=len(set(item.speaker for item in transcript_list)) if transcript_list else 0,
        dialogues=dialogues_list,
        risks=analysis_data.get("risks", [])
    )
    
    return result, call1_result
    
except Exception as e:
    logger.warning(f"解析新格式失败，使用旧格式: {e}")
    # 兼容旧格式
    dialogues_list = []
    if "dialogues" in analysis_data:
        for dialogue in analysis_data["dialogues"]:
            dialogues_list.append(DialogueItem(
                speaker=dialogue.get("speaker", "未知"),
                content=dialogue.get("content", ""),
                tone=dialogue.get("tone", "未知")
            ))
    
    result = AudioAnalysisResponse(
        speaker_count=analysis_data.get("speaker_count", 0),
        dialogues=dialogues_list,
        risks=analysis_data.get("risks", [])
    )
    
    return result, None
```

**注意**: 需要更新函数签名以返回两个值：
```python
async def analyze_audio_from_path(temp_file_path: str, file_filename: str) -> tuple[AudioAnalysisResponse, Optional[Call1Response]]:
```

### 2. 更新 analyze_audio_async 函数

**位置**: `main.py` 第698行附近

**当前代码**:
```python
result = await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")

emotion_score = calculate_emotion_score(result)
tags = generate_tags(result)
```

**需要更新为**:
```python
result, call1_result = await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")

# 使用Call1结果或旧结果
if call1_result:
    emotion_score = call1_result.mood_score
    stats = call1_result.stats
    summary = call1_result.summary
    transcript = call1_result.transcript
else:
    emotion_score = calculate_emotion_score(result)
    stats = {"sigh": 0, "laugh": 0}
    summary = ""
    transcript = []

tags = generate_tags(result)
```

### 3. 更新存储逻辑

**在 analyze_audio_async 函数中**，需要更新 `analysis_storage` 的存储：

```python
analysis_storage[session_id] = {
    "dialogues": [d.dict() for d in result.dialogues],
    "risks": result.risks,
    # 新增Call1数据
    "call1": call1_result.dict() if call1_result else None,
    "mood_score": emotion_score,
    "stats": stats,
    "summary": summary,
    "transcript": [t.dict() for t in transcript] if transcript else []
}
```

### 4. 更新 get_task_detail API

**位置**: `main.py` 第773行附近

**需要添加新的字段**:
```python
analysis_result = analysis_storage.get(session_id, {})

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
    # 新增字段
    mood_score=analysis_result.get("mood_score"),
    stats=analysis_result.get("stats", {}),
    summary=analysis_result.get("summary", ""),
    transcript=analysis_result.get("transcript", []),
    created_at=task_data["created_at"],
    updated_at=task_data["updated_at"]
)
```

**同时需要更新 TaskDetailResponse 模型**:
```python
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
    # 新增字段
    mood_score: Optional[int] = None
    stats: Optional[dict] = None
    summary: Optional[str] = None
    transcript: Optional[List[dict]] = None
    created_at: str
    updated_at: str
```

### 5. 创建 Call #2 API 端点

**新增端点**: `/api/v1/tasks/sessions/{session_id}/strategies`

```python
@app.post("/api/v1/tasks/sessions/{session_id}/strategies")
async def generate_strategies(session_id: str):
    """生成策略分析（Call #2）"""
    from datetime import datetime
    
    try:
        task_data = tasks_storage.get(session_id)
        if not task_data:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        analysis_result = analysis_storage.get(session_id, {})
        transcript = analysis_result.get("transcript", [])
        
        if not transcript:
            raise HTTPException(status_code=400, detail="对话转录数据不存在，请先完成音频分析")
        
        # 构建提示词（使用需求文档中的提示词B）
        prompt = """角色: 你是一位精通博弈论、职场心理学与视觉修辞的深度沟通专家。

任务: 基于 Call #1 提供的对话转录音本，深入拆解双方的权力动态，并提供具备实战价值的应对策略与视觉化方案。

核心指令:
1. **博弈剖析**: 洞察对话文本背后的「权力位阶」与「隐性诉求」。
2. **自主策略研判**: **请勿使用固定分类**。请根据具体场景（如：需求加塞、情感勒索、沟通僵局），自主研判 3 种最具破局可能性的应对路径。每种策略需给出独特的 `label`（如：借力打力、柔性边界、认知对齐）。
3. **视觉建模**: 为当前情境设计一张 1:1 的火柴人绘图描述词 (`image_prompt`)。
   - **构图规则**: 米色背景，极简火柴人线稿，左侧为用户，右侧为对方，专注于展现肢体语言中的情绪（如：耸肩、对峙、闪躲）。
   - 心理 OS: 分别提炼出双方在此刻「想说但没说出口」的内心暗示语 (my_inner, other_inner)。

参数定义:
- **strategies**: 数组，每个策略包含 `id` (策略ID), `label` (风格标签), `emoji`, `title` (策略标题), `content` (Markdown 格式的详细建议与话术)。
- **visual**: 对象，包含 `image_prompt`, `my_inner`, `other_inner`。

要求: 必须以纯 JSON 形式返回，确保结构能直接驱动前端渲染。

返回格式:
{
  "visual": {
    "image_prompt": "...",
    "my_inner": "感到被冒犯但保持礼貌",
    "other_inner": "试探对方的弹性"
  },
  "strategies": [
    {
      "id": "s1",
      "label": "策略标签",
      "emoji": "⚔️",
      "title": "策略标题",
      "content": "### 建议话术\n1. **心理逻辑**: ...\n2. **推荐话术**: '...'"
    }
  ]
}

对话转录:
{transcript_json}
"""
        
        transcript_json = json.dumps([t if isinstance(t, dict) else t.dict() for t in transcript], ensure_ascii=False, indent=2)
        prompt = prompt.format(transcript_json=transcript_json)
        
        # 调用Gemini模型
        model_name = 'gemini-3-flash-preview'
        model = genai.GenerativeModel(model_name)
        
        response = model.generate_content(prompt)
        analysis_data = parse_gemini_response(response.text)
        
        # 构建Call2Response
        visual_data = VisualData(
            image_prompt=analysis_data["visual"]["image_prompt"],
            my_inner=analysis_data["visual"]["my_inner"],
            other_inner=analysis_data["visual"]["other_inner"]
        )
        
        strategies_list = []
        for s in analysis_data["strategies"]:
            strategies_list.append(StrategyItem(
                id=s.get("id", ""),
                label=s.get("label", ""),
                emoji=s.get("emoji", ""),
                title=s.get("title", ""),
                content=s.get("content", "")
            ))
        
        call2_result = Call2Response(
            visual=visual_data,
            strategies=strategies_list
        )
        
        # 存储策略结果
        if "call2" not in analysis_storage[session_id]:
            analysis_storage[session_id]["call2"] = call2_result.dict()
        
        return APIResponse(
            code=200,
            message="success",
            data=call2_result.dict(),
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"生成策略失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"生成策略失败: {str(e)}")
```

## 执行步骤

1. 先更新 `analyze_audio_from_path` 函数
2. 更新 `analyze_audio_async` 函数
3. 更新存储逻辑
4. 更新 `TaskDetailResponse` 模型
5. 更新 `get_task_detail` API
6. 创建 Call #2 API 端点
7. 测试所有API
