#!/bin/bash
# 上传 profiles 和 audio_segments API 文件到服务器并重启服务

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 上传 API 文件到服务器 =========="
echo ""

# 检查文件是否存在
if [ ! -f "api/profiles.py" ]; then
    echo "❌ api/profiles.py 文件不存在"
    exit 1
fi

if [ ! -f "api/audio_segments.py" ]; then
    echo "❌ api/audio_segments.py 文件不存在"
    exit 1
fi

# 1. 上传 api/profiles.py
echo "1. 上传 api/profiles.py..."
scp api/profiles.py $SERVER:$REMOTE_DIR/api/
if [ $? -eq 0 ]; then
    echo "✅ api/profiles.py 上传成功"
else
    echo "❌ api/profiles.py 上传失败"
    exit 1
fi

# 2. 上传 api/audio_segments.py
echo ""
echo "2. 上传 api/audio_segments.py..."
scp api/audio_segments.py $SERVER:$REMOTE_DIR/api/
if [ $? -eq 0 ]; then
    echo "✅ api/audio_segments.py 上传成功"
else
    echo "❌ api/audio_segments.py 上传失败"
    exit 1
fi

# 3. 重启服务
echo ""
echo "3. 重启服务..."
ssh $SERVER << 'EOF'
cd ~/gemini-audio-service
source venv/bin/activate

# 停止旧服务
echo "停止旧服务..."
pkill -f "python.*main.py" || echo "没有运行中的服务"

# 等待进程完全停止
sleep 2

# 启动新服务
echo "启动新服务..."
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &

# 等待服务启动
sleep 5

# 检查服务是否运行
if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    echo ""
    echo "查看最新日志:"
    tail -30 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|profiles|audio|ERROR"
else
    echo "❌ 服务启动失败"
    echo "查看错误日志:"
    tail -50 ~/gemini-audio-service.log
fi

# 测试路由
echo ""
echo "测试路由..."
curl -s http://localhost:8001/api/v1/profiles -H "Authorization: Bearer test" 2>&1 | head -5 || echo "路由测试（预期返回 401 或 403，不是 404）"
EOF

echo ""
echo "========== 更新完成 =========="
echo ""
echo "📋 查看日志: ssh $SERVER 'tail -f ~/gemini-audio-service.log'"
