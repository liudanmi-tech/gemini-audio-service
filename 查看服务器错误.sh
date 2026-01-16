#!/bin/bash

# 在服务器上查看错误日志

echo "========== 查看最近的错误日志 =========="
ssh admin@47.79.254.213 'tail -100 ~/gemini-audio-service.log | tail -50'

echo ""
echo "========== 查看完整的错误信息 =========="
ssh admin@47.79.254.213 'tail -200 ~/gemini-audio-service.log | grep -A 20 -E "ERROR|错误|Exception|Traceback|SyntaxError|ImportError"'

echo ""
echo "========== 检查代码语法 =========="
ssh admin@47.79.254.213 'cd ~/gemini-audio-service && source venv/bin/activate && python3 -m py_compile main.py 2>&1'
