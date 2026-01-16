#!/bin/bash

# 直接诊断任务（不依赖登录）
SESSION_ID="${1:-d12f253d-608e-442d-833b-92e874f1efc5}"

echo "========== 直接诊断任务状态 =========="
echo "Session ID: $SESSION_ID"
echo ""

cd ~/gemini-audio-service
source venv/bin/activate

# 1. 检查数据库中的任务
echo "=== 1. 检查数据库中的任务 ==="
python3 << PYEOF
import sys
sys.path.insert(0, '.')
import asyncio
from database.connection import AsyncSessionLocal
from database.models import Session, AnalysisResult
from sqlalchemy import select
import uuid

async def check():
    async with AsyncSessionLocal() as session:
        session_id = uuid.UUID('$SESSION_ID')
        
        # 检查Session
        result = await session.execute(
            select(Session).where(Session.id == session_id)
        )
        db_session = result.scalar_one_or_none()
        
        if db_session:
            print(f'✅ 找到Session:')
            print(f'   ID: {db_session.id}')
            print(f'   标题: {db_session.title}')
            print(f'   状态: {db_session.status}')
            print(f'   创建时间: {db_session.created_at}')
            print(f'   更新时间: {db_session.updated_at}')
            print(f'   开始时间: {db_session.start_time}')
            print(f'   结束时间: {db_session.end_time}')
            print(f'   时长: {db_session.duration}')
            print(f'   情绪分数: {db_session.emotion_score}')
            print(f'   说话人数: {db_session.speaker_count}')
        else:
            print('❌ 未找到Session')
        
        # 检查AnalysisResult
        result = await session.execute(
            select(AnalysisResult).where(AnalysisResult.session_id == session_id)
        )
        analysis = result.scalar_one_or_none()
        
        if analysis:
            print(f'\\n✅ 找到分析结果:')
            print(f'   ID: {analysis.id}')
            print(f'   对话数量: {len(analysis.dialogues) if analysis.dialogues else 0}')
            print(f'   风险数量: {len(analysis.risks) if analysis.risks else 0}')
            print(f'   情绪分数: {analysis.mood_score}')
            print(f'   创建时间: {analysis.created_at}')
        else:
            print('\\n⚠️  未找到分析结果（可能还在分析中或已失败）')

asyncio.run(check())
PYEOF

echo ""

# 2. 查看相关日志
echo "=== 2. 查看相关日志（最近30行）==="
grep "$SESSION_ID" ~/gemini-audio-service.log | tail -30 || echo "未找到相关日志"

echo ""

# 3. 查看分析任务启动日志
echo "=== 3. 查看分析任务启动日志 ==="
grep -E "开始异步分析|analyze_audio_async|创建异步分析任务" ~/gemini-audio-service.log | grep -i "$SESSION_ID" | tail -10 || echo "未找到分析任务启动日志"

echo ""

# 4. 查看错误日志
echo "=== 4. 查看错误日志 ==="
grep -E "ERROR|错误|Exception|Traceback|失败" ~/gemini-audio-service.log | grep -i "$SESSION_ID" | tail -15 || echo "未找到错误日志"

echo ""

# 5. 查看最近的错误（不限定session_id）
echo "=== 5. 查看最近的错误（所有任务）==="
grep -E "ERROR|错误|Exception" ~/gemini-audio-service.log | tail -10
