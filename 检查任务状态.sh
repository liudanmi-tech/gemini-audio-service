#!/bin/bash

# 检查任务状态和日志
SESSION_ID="9b49e802-3614-43f2-ac8a-4f713cde3012"

echo "=== 1. 检查任务状态 ==="
curl -s -X GET "http://47.79.254.213:8001/api/v1/tasks/sessions/$SESSION_ID/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(curl -s -X POST "http://47.79.254.213:8001/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"phone": "13800138000", "code": "123456"}' | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('data', {}).get('token', ''))" 2>/dev/null)" | python3 -m json.tool

echo -e "\n=== 2. 检查任务详情 ==="
curl -s -X GET "http://47.79.254.213:8001/api/v1/tasks/sessions/$SESSION_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(curl -s -X POST "http://47.79.254.213:8001/api/v1/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"phone": "13800138000", "code": "123456"}' | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('data', {}).get('token', ''))" 2>/dev/null)" | python3 -m json.tool

echo -e "\n=== 3. 查看服务器日志（最近50行）==="
echo "请在服务器上执行: tail -50 ~/gemini-audio-service.log | grep -E 'analyze|$SESSION_ID|ERROR|错误'"
