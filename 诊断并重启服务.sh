#!/bin/bash
# 诊断并重启服务 - 完整版本

cd /home/admin/gemini-audio-service

# 1. 检查文件是否存在
echo "=== 1. 检查文件 ==="
ls -la main.py
ls -la venv/bin/activate

# 2. 激活虚拟环境并检查 Python
echo ""
echo "=== 2. 检查 Python 环境 ==="
. venv/bin/activate
which python3
python3 --version

# 3. 停止旧进程
echo ""
echo "=== 3. 停止旧进程 ==="
pkill -f "python3 main.py" || echo "没有运行中的进程"
sleep 2
ps aux | grep "python3 main.py" | grep -v grep || echo "确认：没有运行中的进程"

# 4. 检查语法
echo ""
echo "=== 4. 检查语法 ==="
python3 -m py_compile main.py && echo "✅ 语法检查通过" || echo "❌ 语法错误"

# 5. 启动服务（前台运行测试）
echo ""
echo "=== 5. 启动服务（测试） ==="
python3 main.py > /home/admin/gemini-service.log 2>&1 &
SERVICE_PID=$!
echo "服务 PID: $SERVICE_PID"

# 6. 等待启动
echo ""
echo "=== 6. 等待服务启动 ==="
sleep 5

# 7. 检查进程
echo ""
echo "=== 7. 检查进程 ==="
ps aux | grep "python3 main.py" | grep -v grep || echo "❌ 进程未运行"

# 8. 检查端口
echo ""
echo "=== 8. 检查端口 ==="
netstat -tlnp | grep 8001 || ss -tlnp | grep 8001 || echo "⚠️  端口 8001 未监听"

# 9. 查看日志（最后 20 行）
echo ""
echo "=== 9. 查看日志（最后 20 行） ==="
tail -20 /home/admin/gemini-service.log 2>/dev/null || echo "日志文件不存在或无法读取"

# 10. 测试健康检查
echo ""
echo "=== 10. 测试健康检查 ==="
curl -v http://localhost:8001/health || echo "❌ 无法连接"

echo ""
echo "=== 完成 ==="

