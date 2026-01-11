#!/bin/bash

echo "🔍 验证服务器服务状态..."
echo ""

# 1. 检查进程
echo "📊 1. 检查进程状态："
ps aux | grep python3 | grep main.py | grep -v grep || echo "❌ 未找到运行中的进程"
echo ""

# 2. 检查端口（需要 sudo）
echo "📊 2. 检查端口监听："
sudo netstat -tlnp | grep 8001 || sudo ss -tlnp | grep 8001 || echo "⚠️  需要 sudo 权限查看端口"
echo ""

# 3. 测试本地 API
echo "🧪 3. 测试本地 API："
curl -s http://localhost:8001/health | python3 -m json.tool || echo "❌ 无法连接到服务"
echo ""

# 4. 测试外部 API（从 Mac）
echo "🧪 4. 测试外部 API（从你的 Mac）："
curl -s http://47.79.254.213:8001/health | python3 -m json.tool || echo "⚠️  无法从外部访问（可能需要配置安全组）"
echo ""

# 5. 查看最近日志
echo "📋 5. 最近的日志（最后 10 行）："
tail -10 /tmp/gemini-service.log 2>/dev/null || echo "⚠️  无法读取日志文件"
echo ""

echo "✅ 验证完成！"
