#!/bin/bash

# 从本地Mac上传main.py到服务器
# 使用方法: ./上传main.py到服务器.sh

echo "=== 上传main.py到服务器 ==="
scp main.py admin@47.79.254.213:~/gemini-audio-service/

if [ $? -eq 0 ]; then
    echo "✅ 上传成功"
    echo ""
    echo "=== 在服务器上重启服务 ==="
    echo "请在服务器上执行以下命令："
    echo ""
    echo "cd ~/gemini-audio-service"
    echo "source venv/bin/activate"
    echo "pkill -f 'python.*main.py'"
    echo "sleep 2"
    echo "nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
    echo "sleep 5"
    echo "ps aux | grep '[p]ython.*main.py'"
else
    echo "❌ 上传失败"
    exit 1
fi
