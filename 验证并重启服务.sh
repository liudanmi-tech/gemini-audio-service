#!/bin/bash

# 验证服务器上的代码并重启服务

echo "========== 1. 重新上传代码 =========="
cd ~/Desktop/AI军师/gemini-audio-service
scp main.py admin@47.79.254.213:~/gemini-audio-service/

echo ""
echo "========== 2. 验证服务器上的代码 =========="
ssh admin@47.79.254.213 'cd ~/gemini-audio-service && source venv/bin/activate && python3 -m py_compile main.py 2>&1 && echo "✅ 语法检查通过" || echo "❌ 语法检查失败"'

echo ""
echo "========== 3. 检查第1124行附近的代码 =========="
ssh admin@47.79.254.213 'sed -n "1120,1130p" ~/gemini-audio-service/main.py'

echo ""
echo "========== 4. 重启服务 =========="
ssh admin@47.79.254.213 'cd ~/gemini-audio-service && source venv/bin/activate && pkill -f "python.*main.py" && sleep 2 && nohup python3 main.py > ~/gemini-audio-service.log 2>&1 & sleep 5 && ps aux | grep "[p]ython.*main.py" && echo "" && tail -30 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|ERROR|错误"'
