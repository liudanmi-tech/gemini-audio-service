#!/bin/bash
# 502 时在服务器上启动/重启 Python 应用（本机执行，通过 SSH）
# 用法：./恢复502_启动应用.sh

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

echo "========== 恢复 502：在服务器上启动应用 =========="
echo "服务器: $SERVER"
echo ""

ssh -o ConnectTimeout=15 "$SERVER" bash -s << 'REMOTE'
set -e
cd ~/gemini-audio-service
source venv/bin/activate 2>/dev/null || true

echo "停止旧进程..."
pkill -f "python.*main.py" 2>/dev/null || true
pkill -f "uvicorn main:app" 2>/dev/null || true
sleep 2

echo "启动应用（端口 8000）..."
nohup python3 main.py >> ~/gemini-audio-service.log 2>&1 &
sleep 2

echo "等待应用就绪（约 20s）..."
sleep 18

if curl -sf --connect-timeout 5 http://127.0.0.1:8000/health > /dev/null 2>&1; then
  echo "✅ 应用已启动，8000/health 正常"
  tail -5 ~/gemini-audio-service.log | grep -E "Uvicorn|startup|Application" || tail -3 ~/gemini-audio-service.log
else
  echo "⚠️ 健康检查未通过，请稍等 30 秒后重试客户端，或查看日志："
  echo "   tail -80 ~/gemini-audio-service.log"
fi
REMOTE

echo ""
echo "========== 完成 =========="
echo "若仍 502，请执行: ssh $SERVER 'tail -100 ~/gemini-audio-service.log'"
