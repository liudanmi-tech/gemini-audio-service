#!/bin/bash

# 自动测试并修复任务详情接口问题

cd ~/gemini-audio-service
source venv/bin/activate

echo "========== 自动测试并修复任务详情接口 =========="
echo ""

# 1. 发送验证码并登录
echo "=== 步骤1: 获取Token ==="
curl -s -X POST "http://localhost:8001/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}' > /dev/null

sleep 2

LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8001/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000", "code": "123456"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('data', {}).get('token', ''))" 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" == "None" ]; then
    echo "❌ 获取Token失败，请检查验证码"
    echo "$LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Token获取成功"
echo ""

# 2. 获取任务列表
echo "=== 步骤2: 获取任务列表 ==="
TASK_LIST=$(curl -s -X GET "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=1" \
  -H "Authorization: Bearer $TOKEN")

SESSION_ID=$(echo "$TASK_LIST" | python3 -c "import sys, json; data=json.load(sys.stdin); sessions=data.get('data', {}).get('sessions', []); print(sessions[0]['session_id'] if sessions else '')" 2>/dev/null)

if [ -z "$SESSION_ID" ]; then
    echo "⚠️ 从任务列表获取session_id失败，使用提供的session_id"
    SESSION_ID="6576aab2-e536-4ab8-94b9-50aa86438b21"
else
    echo "✅ Session ID: $SESSION_ID"
fi
echo ""

# 3. 测试任务详情接口
echo "=== 步骤3: 测试任务详情接口（带超时）==="
START_TIME=$(date +%s)
RESPONSE=$(curl -s --max-time 30 -X GET "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID" \
  -H "Authorization: Bearer $TOKEN")
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

echo "响应时间: ${ELAPSED}秒"
echo ""

# 检查响应
if echo "$RESPONSE" | grep -q '"code":200'; then
    echo "✅ 接口响应成功"
    echo "$RESPONSE" | python3 -m json.tool | head -30
    echo ""
    echo "✅ 任务详情接口工作正常，响应时间: ${ELAPSED}秒"
    if [ $ELAPSED -gt 10 ]; then
        echo "⚠️ 警告: 响应时间较长（${ELAPSED}秒），可能需要优化"
    fi
else
    echo "❌ 接口响应失败"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
    echo ""
    echo "=== 检查服务器日志 ==="
    tail -50 ~/gemini-audio-service.log | grep -E "ERROR|错误|任务详情|get_task_detail|$SESSION_ID" | tail -10
fi

echo ""
echo "=== 步骤4: 检查数据库查询性能 ==="
python3 << 'PYTHON'
import asyncio
import time
from database.connection import AsyncSessionLocal
from database.models import Session, AnalysisResult
from sqlalchemy import select
import uuid

async def test_query_performance():
    session_id = "$SESSION_ID"
    try:
        session_uuid = uuid.UUID(session_id)
    except:
        print(f"❌ 无效的session_id: {session_id}")
        return
    
    async with AsyncSessionLocal() as db:
        start_time = time.time()
        
        # 测试Session查询
        result = await db.execute(
            select(Session).where(Session.id == session_uuid)
        )
        session = result.scalar_one_or_none()
        session_time = time.time() - start_time
        
        print(f"Session查询时间: {session_time:.3f}秒")
        
        if session:
            # 测试AnalysisResult查询
            start_time = time.time()
            analysis_result = await db.execute(
                select(AnalysisResult).where(AnalysisResult.session_id == session_uuid)
            )
            analysis = analysis_result.scalar_one_or_none()
            analysis_time = time.time() - start_time
            
            print(f"AnalysisResult查询时间: {analysis_time:.3f}秒")
            print(f"总查询时间: {session_time + analysis_time:.3f}秒")
            
            if session_time + analysis_time > 1.0:
                print("⚠️ 警告: 数据库查询较慢，可能需要优化索引")
        else:
            print(f"❌ Session不存在: {session_id}")

asyncio.run(test_query_performance())
PYTHON

echo ""
echo "========== 测试完成 =========="
