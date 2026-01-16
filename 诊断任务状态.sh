#!/bin/bash

# 诊断任务状态脚本
# 使用方法: ./诊断任务状态.sh [session_id]

SESSION_ID="${1:-d12f253d-608e-442d-833b-92e874f1efc5}"

echo "========== 诊断任务状态 =========="
echo "Session ID: $SESSION_ID"
echo ""

# 1. 登录获取Token
echo "=== 1. 登录获取Token ==="
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8001/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000", "code": "123456"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    token = data.get('data', {}).get('token', '')
    print(token)
except:
    pass
" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "❌ 登录失败"
    echo "$LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Token获取成功: ${TOKEN:0:50}..."
echo ""

# 2. 检查任务状态
echo "=== 2. 检查任务状态 ==="
STATUS_RESPONSE=$(curl -s -X GET "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID/status" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "$STATUS_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$STATUS_RESPONSE"
echo ""

# 3. 检查任务详情
echo "=== 3. 检查任务详情 ==="
DETAIL_RESPONSE=$(curl -s -X GET "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json")

echo "$DETAIL_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$DETAIL_RESPONSE"
echo ""

# 4. 检查数据库中的任务
echo "=== 4. 检查数据库中的任务 ==="
cd ~/gemini-audio-service
source venv/bin/activate

python3 -c "
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
        else:
            print('\\n⚠️  未找到分析结果（可能还在分析中）')

asyncio.run(check())
"

echo ""

# 5. 查看相关日志
echo "=== 5. 查看相关日志（最近20行）==="
grep "$SESSION_ID" ~/gemini-audio-service.log | tail -20 || echo "未找到相关日志"

echo ""

# 6. 查看错误日志
echo "=== 6. 查看错误日志（最近10行）==="
grep -E "ERROR|错误|Exception|Traceback|失败" ~/gemini-audio-service.log | grep -i "$SESSION_ID" | tail -10 || echo "未找到错误日志"

echo ""

# 7. 查看分析相关的日志
echo "=== 7. 查看分析相关日志（最近10行）==="
grep -E "开始异步分析|analyze_audio_async|分析音频" ~/gemini-audio-service.log | grep -i "$SESSION_ID" | tail -10 || echo "未找到分析日志"
