#!/bin/bash

# 在服务器上执行：重启服务以应用最新代码

echo "========== 检查当前代码版本 =========="
cd ~/gemini-audio-service
grep -A 3 "class VisualData" main.py | head -5

echo ""
echo "========== 停止旧服务 =========="
pkill -f 'python.*main.py'
sleep 2

echo ""
echo "========== 启动新服务 =========="
source venv/bin/activate
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 3

echo ""
echo "========== 检查服务状态 =========="
ps aux | grep 'python.*main.py' | grep -v grep

echo ""
echo "========== 测试健康检查 =========="
curl -s http://localhost:8001/health | python3 -m json.tool

echo ""
echo "✅ 服务重启完成！"
