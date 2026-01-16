#!/bin/bash

# 上传main.py到服务器并重启服务（正确版本）
# 在本地Mac上执行

echo "========== 上传代码到服务器 =========="
echo ""

# 检查文件是否存在
if [ ! -f "main.py" ]; then
    echo "❌ main.py 文件不存在"
    exit 1
fi

echo "=== 1. 上传main.py到服务器 ==="
scp main.py admin@47.79.254.213:~/gemini-audio-service/

if [ $? -eq 0 ]; then
    echo "✅ 上传成功"
else
    echo "❌ 上传失败"
    exit 1
fi

echo ""
echo "=== 2. 在服务器上重启服务 ==="

# 使用heredoc避免引号问题
ssh admin@47.79.254.213 << 'SSH_EOF'
cd ~/gemini-audio-service
source venv/bin/activate

# 停止旧服务
pkill -f 'python.*main.py'
sleep 2

# 启动新服务
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 5

# 检查服务状态
echo "=== 服务进程 ==="
ps aux | grep '[p]ython.*main.py'

echo ""
echo "=== 启动日志 ==="
tail -30 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|数据库|Database"
SSH_EOF

echo ""
echo "✅ 完成！"
