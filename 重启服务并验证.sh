#!/bin/bash

# 在服务器上重启服务并验证

echo "========== 重启服务 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service
source venv/bin/activate

# 停止旧服务
pkill -f 'python.*main.py'
sleep 2

# 启动新服务
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 5

# 检查服务状态
echo "=== 服务进程 ==="
ps aux | grep '[p]ython.*main.py'

echo ""
echo "=== 启动日志 ==="
tail -50 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|ERROR|错误|监听|listening|running"

echo ""
echo "=== 测试健康检查 ==="
curl -s http://localhost:8001/ | head -5 || echo "服务未启动或接口不存在"
EOF
