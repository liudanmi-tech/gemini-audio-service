#!/bin/bash

# 验证服务是否正常启动

echo "========== 验证服务启动 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

echo "=== 1. 检查服务进程 ==="
ps aux | grep '[p]ython.*main.py'

echo ""
echo "=== 2. 查看最近的启动日志 ==="
tail -50 ~/gemini-audio-service.log | tail -30

echo ""
echo "=== 3. 测试健康检查接口 ==="
curl -s http://localhost:8001/ | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8001/

echo ""
echo "=== 4. 测试端口监听 ==="
netstat -tlnp | grep 8001 || ss -tlnp | grep 8001
EOF
