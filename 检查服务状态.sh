#!/bin/bash

# 检查服务器服务状态和最新日志

echo "========== 检查服务进程 =========="
ssh admin@47.79.254.213 "ps aux | grep 'python.*main.py' | grep -v grep"

echo ""
echo "========== 查看最新日志（最近50行） =========="
ssh admin@47.79.254.213 "tail -50 ~/gemini-audio-service.log"

echo ""
echo "========== 查看上传相关的日志 =========="
ssh admin@47.79.254.213 "grep -i '收到音频上传请求\|准备返回响应\|upload\|audio' ~/gemini-audio-service.log | tail -20"

echo ""
echo "========== 测试健康检查 =========="
curl -s http://47.79.254.213:8001/health | python3 -m json.tool || echo "无法连接"
