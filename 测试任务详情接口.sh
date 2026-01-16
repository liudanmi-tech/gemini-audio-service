#!/bin/bash

# 测试任务详情接口是否正常

echo "========== 测试任务详情接口 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

# 先获取一个有效的session_id和token
echo "=== 1. 获取Token ==="
TOKEN=$(curl -s -X POST "http://localhost:8001/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}' | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['code'])")

sleep 2

LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8001/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000", "code": "123456"}')

TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['token'])" 2>/dev/null)

if [ -z "$TOKEN" ] || [ "$TOKEN" == "None" ]; then
    echo "❌ 获取Token失败"
    echo "$LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Token获取成功"

echo ""
echo "=== 2. 获取任务列表（获取一个session_id）==="
TASK_LIST=$(curl -s -X GET "http://localhost:8001/api/v1/tasks/sessions?page=1&page_size=1" \
  -H "Authorization: Bearer $TOKEN")

SESSION_ID=$(echo "$TASK_LIST" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['data']['sessions'][0]['session_id'] if data.get('data') and data['data'].get('sessions') else '')" 2>/dev/null)

if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" == "None" ]; then
    echo "❌ 获取session_id失败"
    echo "$TASK_LIST"
    exit 1
fi

echo "✅ Session ID: $SESSION_ID"

echo ""
echo "=== 3. 测试任务详情接口（带超时）==="
time curl -s --max-time 10 -X GET "http://localhost:8001/api/v1/tasks/sessions/$SESSION_ID" \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool | head -20

echo ""
echo "=== 4. 检查服务器日志（最近的错误）==="
tail -50 ~/gemini-audio-service.log | grep -E "ERROR|错误|任务详情|get_task_detail" | tail -10
EOF
