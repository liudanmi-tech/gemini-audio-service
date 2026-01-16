#!/bin/bash

# 在本地Mac上测试远程服务器的接口
# 使用方法：bash 本地测试远程服务器.sh

SERVER_URL="http://47.79.254.213:8001"

echo "========== 测试远程服务器任务详情接口 =========="
echo "服务器地址: $SERVER_URL"
echo ""

# 1. 发送验证码
echo "=== 步骤1: 发送验证码 ==="
curl -s -X POST "$SERVER_URL/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}' | python3 -m json.tool

sleep 2

# 2. 登录获取Token
echo ""
echo "=== 步骤2: 登录获取Token ==="
LOGIN_RESPONSE=$(curl -s -X POST "$SERVER_URL/api/v1/auth/login" \
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
TASK_LIST=$(curl -s -X GET "$SERVER_URL/api/v1/tasks/sessions?page=1&page_size=1" \
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
echo "URL: $SERVER_URL/api/v1/tasks/sessions/$SESSION_ID"
echo ""

START_TIME=$(date +%s)
RESPONSE=$(curl -s --max-time 30 -X GET "$SERVER_URL/api/v1/tasks/sessions/$SESSION_ID" \
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
    
    if [ $ELAPSED -gt 10 ]; then
        echo "⚠️ 警告: 响应时间较长（${ELAPSED}秒），可能需要优化"
    else
        echo "✅ 响应时间正常（${ELAPSED}秒）"
    fi
else
    echo "❌ 接口响应失败"
    echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"
fi

echo ""
echo "========== 测试完成 =========="
