#!/bin/bash

echo "🔧 修复并重启服务器服务..."
echo ""

# 1. 上传修复后的 main.py
echo "📤 上传修复后的 main.py..."
scp main.py admin@47.79.254.213:~/gemini-audio-service/main.py

# 2. 在服务器上重启服务
echo ""
echo "🔄 在服务器上重启服务..."
ssh admin@47.79.254.213 << 'EOF'
cd ~/gemini-audio-service
source venv/bin/activate

# 停止旧进程
pkill -f "python3 main.py"

# 等待进程停止
sleep 2

# 检查语法
python3 -m py_compile main.py

if [ $? -eq 0 ]; then
    echo "✅ 语法检查通过"
    
    # 启动服务
    nohup python3 main.py > /tmp/gemini-service.log 2>&1 &
    
    sleep 3
    
    # 检查进程
    ps aux | grep python3 | grep main.py | grep -v grep
    
    # 测试健康检查
    echo ""
    echo "🧪 测试健康检查："
    curl http://localhost:8001/health
    
    echo ""
    echo "✅ 服务已重启"
else
    echo "❌ 语法检查失败，请检查错误"
fi
EOF

echo ""
echo "✅ 完成！"


