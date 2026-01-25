#!/bin/bash
# 在服务器上执行的检查和重启命令

echo "========== 检查服务器代码 =========="

# 1. 检查 api/profiles.py 的路由前缀
echo "1. 检查 api/profiles.py 的路由前缀..."
grep "router = APIRouter" api/profiles.py

# 2. 检查 main.py 中的路由注册
echo ""
echo "2. 检查 main.py 中的路由注册..."
grep "profiles_router" main.py

# 3. 检查服务是否运行
echo ""
echo "3. 检查服务是否运行..."
ps aux | grep "[p]ython.*main.py" || echo "服务未运行"

# 4. 停止旧服务
echo ""
echo "4. 停止旧服务..."
pkill -f "python.*main.py" || echo "没有运行中的服务"
sleep 2

# 5. 激活虚拟环境并测试导入
echo ""
echo "5. 测试导入路由..."
source venv/bin/activate
python3 -c "
from api.profiles import router
print(f'✅ profiles 路由前缀: {router.prefix}')
" || echo "❌ 导入失败，检查错误"

# 6. 启动服务
echo ""
echo "6. 启动服务..."
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &

sleep 5

# 7. 检查服务是否启动
echo ""
echo "7. 检查服务是否启动..."
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

# 8. 测试路由
echo ""
echo "8. 测试路由（等待 3 秒后测试）..."
sleep 3
echo "测试 GET /api/v1/profiles:"
curl -s http://localhost:8001/api/v1/profiles 2>&1 | head -3
echo ""

# 9. 列出所有路由
echo ""
echo "9. 列出所有注册的路由..."
python3 -c "
from main import app
print('已注册的路由:')
for route in app.routes:
    if hasattr(route, 'path'):
        methods = getattr(route, 'methods', set())
        method_str = ', '.join(methods) if methods else 'GET'
        print(f'  {method_str:6} {route.path}')
" 2>&1 | head -20

echo ""
echo "========== 检查完成 =========="
