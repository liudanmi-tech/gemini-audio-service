#!/bin/bash

# 查看服务器上的最新错误

echo "========== 查看最新的错误日志 =========="
ssh admin@47.79.254.213 'tail -100 ~/gemini-audio-service.log | tail -50'

echo ""
echo "========== 查看完整的错误信息 =========="
ssh admin@47.79.254.213 'tail -200 ~/gemini-audio-service.log | grep -A 30 -E "ERROR|错误|Exception|Traceback|SyntaxError|ImportError|NameError"'
