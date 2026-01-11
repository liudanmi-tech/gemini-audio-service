#!/bin/bash
API_BASE="http://47.79.254.213:8001"

echo "📤 1. 上传音频..."
UPLOAD_RESPONSE=$(curl -s -X POST "$API_BASE/api/v1/audio/upload" \
  -F "file=@/Users/liudan/Downloads/GDG.mp3" \
  -F "title=测试录音")

echo "$UPLOAD_RESPONSE" | python3 -m json.tool

# 提取 session_id
SESSION_ID=$(echo "$UPLOAD_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['data']['session_id'])")

echo -e "\n📋 Session ID: $SESSION_ID"
echo -e "\n⏳ 等待分析完成（30秒）..."
sleep 30

echo -e "\n📊 2. 检查任务状态..."
curl -s "$API_BASE/api/v1/tasks/sessions/$SESSION_ID/status" | python3 -m json.tool

echo -e "\n📝 3. 获取任务详情..."
curl -s "$API_BASE/api/v1/tasks/sessions/$SESSION_ID" | python3 -m json.tool

echo -e "\n🎯 4. 生成策略分析..."
curl -s -X POST "$API_BASE/api/v1/tasks/sessions/$SESSION_ID/strategies" | python3 -m json.tool
