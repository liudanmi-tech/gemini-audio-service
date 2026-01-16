#!/bin/bash

# 查看服务器日志脚本
# 用于诊断音频上传问题

SERVER="admin@47.79.254.213"
LOG_FILE="~/gemini-audio-service.log"

echo "========== 查看服务器日志 =========="
echo "服务器: $SERVER"
echo "日志文件: $LOG_FILE"
echo ""

echo "========== 最近的 50 行日志 =========="
ssh $SERVER "tail -50 $LOG_FILE"

echo ""
echo "========== 查找上传相关的日志 =========="
ssh $SERVER "grep -i 'upload\|audio\|收到音频上传请求\|准备返回响应' $LOG_FILE | tail -30"

echo ""
echo "========== 查找错误日志 =========="
ssh $SERVER "grep -i 'error\|exception\|失败\|traceback' $LOG_FILE | tail -20"

echo ""
echo "========== 检查服务是否运行 =========="
ssh $SERVER "ps aux | grep 'python.*main.py' | grep -v grep"

echo ""
echo "========== 测试健康检查端点 =========="
curl -s http://47.79.254.213:8001/health | python3 -m json.tool || echo "无法连接"
