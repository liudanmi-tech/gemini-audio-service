#!/bin/bash
# 上传 main.py（监听 8000 与 Nginx 一致）到服务器并重启，修复档案列表空响应、技能列表超时

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 上传 main.py（端口 8000）并重启 =========="
echo ""

echo "1. 上传 main.py ..."
scp main.py $SERVER:$REMOTE_DIR/
if [ $? -ne 0 ]; then
    echo "❌ 上传失败"
    exit 1
fi
echo "✅ main.py 上传成功"
echo ""

echo "2. 重启服务（监听 8000，与 Nginx proxy_pass 一致）..."
ssh $SERVER << 'EOF'
cd ~/gemini-audio-service
source venv/bin/activate 2>/dev/null || true

pkill -f "python.*main.py" || echo "没有运行中的服务"
sleep 2

nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 5

if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动（端口 8000）"
    tail -15 ~/gemini-audio-service.log | grep -E "Uvicorn|8000|Application startup|ERROR" || tail -8 ~/gemini-audio-service.log
else
    echo "❌ 服务启动失败"
    tail -50 ~/gemini-audio-service.log
fi
EOF

echo ""
echo "========== 完成。请用客户端重试档案列表、技能列表 =========="
