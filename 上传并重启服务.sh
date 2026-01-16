#!/bin/bash

# 上传main.py到服务器并重启服务
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
echo "执行以下命令："
echo ""
echo "ssh admin@47.79.254.213 'cd ~/gemini-audio-service && source venv/bin/activate && pkill -f \"python.*main.py\" && sleep 2 && nohup python3 main.py > ~/gemini-audio-service.log 2>&1 & && sleep 5 && ps aux | grep \"[p]ython.*main.py\"'"

echo ""
read -p "是否现在执行重启命令？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ssh admin@47.79.254.213 "cd ~/gemini-audio-service && source venv/bin/activate && pkill -f 'python.*main.py' && sleep 2 && nohup python3 main.py > ~/gemini-audio-service.log 2>&1 & && sleep 5 && ps aux | grep '[p]ython.*main.py'"
fi
