#!/bin/bash
# 重启服务并测试图片上传API

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 重启服务 =========="
echo ""

ssh $SERVER << 'EOF'
cd ~/gemini-audio-service

# 停止旧服务
echo "停止旧服务..."
pkill -f "python.*main.py" || echo "没有运行中的服务"
sleep 2

# 启动服务
echo "启动服务..."
source venv/bin/activate
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 5

# 检查服务状态
echo ""
echo "检查服务状态..."
if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    echo ""
    echo "查看启动日志:"
    tail -20 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|ERROR|upload-photo"
else
    echo "❌ 服务启动失败"
    echo "查看错误日志:"
    tail -50 ~/gemini-audio-service.log
fi

# 测试图片上传API路由
echo ""
echo "测试图片上传API路由..."
python3 -c "
from main import app
routes = [r.path for r in app.routes if hasattr(r, 'path') and 'upload-photo' in r.path]
if routes:
    print('✅ 图片上传路由已注册:')
    for r in routes:
        print(f'  {r}')
else:
    print('❌ 图片上传路由未找到')
" 2>&1 | head -10
EOF

echo ""
echo "========== 完成 =========="
