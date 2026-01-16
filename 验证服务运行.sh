#!/bin/bash

# 验证服务是否正常运行

echo "========== 验证服务运行 =========="
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service

echo "=== 1. 检查服务进程 ==="
ps aux | grep '[p]ython.*main.py'

echo ""
echo "=== 2. 查看启动日志 ==="
tail -50 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|监听|listening|running|ERROR|错误" | tail -10

echo ""
echo "=== 3. 测试健康检查接口 ==="
curl -s http://localhost:8001/ | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8001/

echo ""
echo "=== 4. 测试端口监听 ==="
netstat -tlnp | grep 8001 || ss -tlnp | grep 8001

echo ""
echo "=== 5. 测试认证接口（发送验证码）==="
curl -X POST "http://localhost:8001/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}' | python3 -m json.tool 2>/dev/null || curl -X POST "http://localhost:8001/api/v1/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"phone": "13800138000"}'
EOF
