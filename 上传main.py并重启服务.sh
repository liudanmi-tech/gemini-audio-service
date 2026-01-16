#!/bin/bash

echo "========== 上传 main.py 到服务器 =========="

# 上传 main.py
scp main.py admin@47.79.254.213:~/gemini-audio-service/main.py

if [ $? -eq 0 ]; then
    echo "✅ main.py 上传成功！"
    echo ""
    echo "========== 下一步：在服务器上重启服务 =========="
    echo ""
    echo "SSH 登录服务器后执行："
    echo "  cd ~/gemini-audio-service"
    echo "  source venv/bin/activate"
    echo "  pkill -f 'python.*main.py'"
    echo "  sleep 2"
    echo "  nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &"
    echo "  sleep 3"
    echo "  ps aux | grep '[p]ython.*main.py'"
    echo "  tail -30 ~/gemini-audio-service.log | grep -E 'OSS|配置成功'"
    echo ""
    echo "========== 或者一键执行 =========="
    echo "ssh admin@47.79.254.213 'cd ~/gemini-audio-service && source venv/bin/activate && pkill -f \"python.*main.py\" && sleep 2 && nohup python3 main.py > ~/gemini-audio-service.log 2>&1 & sleep 3 && tail -30 ~/gemini-audio-service.log | grep -E \"OSS|配置成功\"'"
else
    echo "❌ 上传失败，请检查网络连接"
    exit 1
fi
