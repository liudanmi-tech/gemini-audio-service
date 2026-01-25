#!/bin/bash
# 在服务器上检查并修复路由问题

SERVER="admin@47.79.254.213"

echo "========== 在服务器上检查和修复 =========="
echo ""

ssh $SERVER << 'EOF'
cd ~/gemini-audio-service

echo "1. 检查 api/profiles.py 的路由前缀..."
grep "router = APIRouter" api/profiles.py || echo "❌ 未找到路由定义"

echo ""
echo "2. 检查 main.py 中的路由注册..."
grep "profiles_router" main.py || echo "❌ 未找到路由注册"

echo ""
echo "3. 检查服务是否运行..."
ps aux | grep "[p]ython.*main.py" || echo "❌ 服务未运行"

echo ""
echo "4. 停止旧服务..."
pkill -f "python.*main.py" || echo "没有运行中的服务"
sleep 2

echo ""
echo "5. 检查 Python 环境..."
source venv/bin/activate
python3 --version

echo ""
echo "6. 测试导入路由..."
python3 -c "
from api.profiles import router
print(f'✅ profiles 路由前缀: {router.prefix}')
" || echo "❌ 导入失败"

echo ""
echo "7. 启动服务..."
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &

sleep 5

echo ""
echo "8. 检查服务是否启动..."
if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    echo ""
    echo "查看最新日志:"
    tail -30 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|profiles|ERROR|WARNING"
else
    echo "❌ 服务启动失败"
    echo "查看错误日志:"
    tail -50 ~/gemini-audio-service.log
fi

echo ""
echo "9. 测试路由（等待 3 秒后测试）..."
sleep 3
curl -s http://localhost:8001/api/v1/profiles 2>&1 | head -3
echo ""

echo ""
echo "10. 检查所有注册的路由..."
python3 -c "
from main import app
for route in app.routes:
    if hasattr(route, 'path'):
        print(f'路由: {route.path}')
" 2>&1 | grep -i profile || echo "未找到 profiles 路由"
EOF

echo ""
echo "========== 检查完成 =========="
