#!/bin/bash

# 在服务器上检查启动错误

echo "========== 检查服务启动错误 =========="
echo ""

cd ~/gemini-audio-service

echo "=== 1. 查看最近的错误日志 ==="
tail -100 ~/gemini-audio-service.log | tail -50

echo ""
echo "=== 2. 查看完整的错误信息 ==="
tail -200 ~/gemini-audio-service.log | grep -A 20 -E "ERROR|错误|Exception|Traceback|SyntaxError|ImportError"

echo ""
echo "=== 3. 检查代码语法 ==="
source venv/bin/activate
python3 -m py_compile main.py 2>&1

echo ""
echo "=== 4. 尝试手动运行查看实时错误 ==="
echo "执行: python3 main.py"
echo "（按Ctrl+C停止）"
