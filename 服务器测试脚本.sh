#!/bin/bash

# 在服务器上直接执行的完整测试脚本
# 使用方法：在服务器上执行：bash 服务器测试脚本.sh

cd ~/gemini-audio-service
source venv/bin/activate

echo "========== 自动测试任务详情接口 =========="
echo ""

# 1. 发送验证码
echo "=== 步骤1: 发送验证码 ==="
curl -s -X POST "http://localhost:8001/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}' | python3 -m json.tool

sleep 2

# 2. 登录获取Token
echo ""
echo "=== 步骤2: 登录获取Token ==="
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8001/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000", "code": "123456"}')

echo "$LOGIN_RESPONSE" | python3 -m json.tool

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('token', ''))" 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" == "None" ]; then
    echo ""
    echo "❌ 获取Token失败"
    echo "响应: $LOGIN_RESPONSE"
    exit 1
fi

echo ""
echo "✅ Token获取成功: ${TOKEN:0:20}..."

# 3. 获取任务列表
echo ""
echo "=== 步骤3: 获取任务列表 ==="
TASK_LIST=$(curl -s -X GET "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=1" \
  -H "Authorization: Bearer $TOKEN")

echo "$TASK_LIST" | python3 -m json.tool | head -20

SESSION_ID=$(echo "$TASK_LIST" | python3 -c "import sys, json; data=json.load(sys.stdin); sessions=data.get('data', {}).get('sessions', []); print(sessions[0]['session_id'] if sessions else '')" 2>/dev/null)

if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" == "None" ]; then
    echo ""
    echo "⚠️ 从任务列表获取session_id失败，使用提供的session_id"
    SESSION_ID="6576aab2-e536-4ab8-94b9-50aa86438b21"
else
    echo ""
    echo "✅ Session ID: $SESSION_ID"
fi

# 4. 测试任务详情接口
echo ""
echo "=== 步骤4: 测试任务详情接口（带超时）==="
echo "URL: http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID"
echo ""

START_TIME=$(date +%s.%N)
RESPONSE=$(curl -s --max-time 30 -X GET "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID" \
  -H "Authorization: Bearer $TOKEN")
END_TIME=$(date +%s.%N)
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)

echo "响应时间: ${ELAPSED}秒"
echo ""

# 检查响应
if echo "$RESPONSE" | grep -q '"code":200'; then
    echo "✅ 接口响应成功"
    echo "$RESPONSE" | python3 -m json.tool | head -30
    echo ""
    
    # 检查响应时间
    ELAPSED_INT=$(echo "$ELAPSED" | cut -d. -f1)
    if [ "$ELAPSED_INT" -gt 10 ]; then
        echo "⚠️ 警告: 响应时间较长（${ELAPSED}秒），可能需要优化"
    else
        echo "✅ 响应时间正常（${ELAPSED}秒）"
    fi
else
    echo "❌ 接口响应失败"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
fi

# 5. 检查服务器日志
echo ""
echo "=== 步骤5: 检查服务器日志（最近的错误）==="
tail -50 ~/gemini-audio-service.log | grep -E "ERROR|错误|任务详情|get_task_detail|$SESSION_ID" | tail -10 || echo "没有相关错误日志"

# 6. 测试数据库查询性能
echo ""
echo "=== 步骤6: 测试数据库查询性能 ==="
python3 << PYTHON_SCRIPT
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
    except Exception as e:
        print(f"❌ 无效的session_id: {session_id}, 错误: {e}")
        return
    
    async with AsyncSessionLocal() as db:
        # 测试Session查询
        start_time = time.time()
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
                print("✅ 数据库查询性能正常")
        else:
            print(f"⚠️ Session不存在: {session_id}")

asyncio.run(test_query_performance())
PYTHON_SCRIPT

echo ""
echo "========== 测试完成 =========="
