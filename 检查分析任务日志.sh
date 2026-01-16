#!/bin/bash

# 检查分析任务日志
SESSION_ID="d12f253d-608e-442d-833b-92e874f1efc5"

echo "========== 检查分析任务日志 =========="
echo ""

cd ~/gemini-audio-service

echo "=== 1. 查看该任务的所有日志 ==="
grep "$SESSION_ID" ~/gemini-audio-service.log | tail -30

echo ""
echo "=== 2. 查看是否有分析任务启动 ==="
grep -E "开始异步分析|analyze_audio_async|创建异步分析任务" ~/gemini-audio-service.log | grep -i "$SESSION_ID"

echo ""
echo "=== 3. 查看最近的错误日志 ==="
grep -E "ERROR|错误|Exception|Traceback" ~/gemini-audio-service.log | tail -20

echo ""
echo "=== 4. 检查代码版本（analyze_audio_async函数）==="
grep -A 3 "async def analyze_audio_async" main.py | head -5

echo ""
echo "=== 5. 检查是否创建了新的数据库会话 ==="
grep -A 10 "async def analyze_audio_async" main.py | grep -E "AsyncSessionLocal|async with.*db"
