#!/bin/bash

# 测试任务详情接口（完整版，包含发送验证码）

cd ~/gemini-audio-service

echo "=== 1. 发送验证码 ==="
curl -s -X POST "http://localhost:8001/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}' | python3 -m json.tool

echo ""
echo "等待2秒..."
sleep 2

echo ""
echo "=== 2. 登录获取Token ==="
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8001/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000", "code": "123456"}')

echo "$LOGIN_RESPONSE" | python3 -m json.tool

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('data', {}).get('token', ''))" 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" == "None" ]; then
    echo ""
    echo "❌ 获取Token失败"
    echo "响应内容: $LOGIN_RESPONSE"
    echo ""
    echo "请检查："
    echo "1. 验证码是否正确（使用123456）"
    echo "2. 验证码是否过期（需要重新发送）"
    exit 1
fi

echo ""
echo "✅ Token获取成功: ${TOKEN:0:20}..."

echo ""
echo "=== 3. 获取任务列表（获取一个session_id）==="
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

echo ""
echo "=== 4. 测试任务详情接口 ==="
echo "URL: http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID"
echo ""

RESPONSE=$(time curl -s --max-time 30 -X GET "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID" \
  -H "Authorization: Bearer $TOKEN")

echo "$RESPONSE" | python3 -m json.tool | head -50

echo ""
echo "=== 5. 检查响应状态 ==="
STATUS_CODE=$(echo "$RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('code', 'unknown'))" 2>/dev/null)
if [ "$STATUS_CODE" == "200" ]; then
    echo "✅ 接口响应成功"
else
    echo "❌ 接口响应失败，状态码: $STATUS_CODE"
    echo "完整响应: $RESPONSE"
fi
