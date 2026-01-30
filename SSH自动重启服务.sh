#!/bin/bash
# 通过 SSH 在服务器上自动执行：重启应用并检查状态
# 使用前请确保本机已配置 SSH 免密：ssh admin@服务器 无需输入密码
#
# 配置方式（任选其一）：
#   1. 创建 .deploy.env（不要提交到 git）：
#      DEPLOY_SERVER=admin@你的服务器IP或主机名
#   2. 或运行前 export：export DEPLOY_SERVER=admin@iZt4netdjt0adf5p1zrsbaZ
#
# 用法：./SSH自动重启服务.sh  或  bash SSH自动重启服务.sh

set -e

LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-~/gemini-audio-service}"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

if [ -f "$LOCAL_DIR/.deploy.env" ]; then
  set -a
  source "$LOCAL_DIR/.deploy.env"
  set +a
  SERVER="${DEPLOY_SERVER:-$SERVER}"
  REMOTE_DIR="${DEPLOY_REMOTE_DIR:-$REMOTE_DIR}"
fi

echo "========== SSH 自动重启服务 =========="
echo "服务器: $SERVER"
echo "远程目录: $REMOTE_DIR"
echo ""

ssh "$SERVER" << SSH_EOF
set -e
cd $REMOTE_DIR
source venv/bin/activate 2>/dev/null || true

echo "=== 停止旧进程 ==="
pkill -f "uvicorn main:app" 2>/dev/null || true
pkill -f "python.*main.py"  2>/dev/null || true
sleep 2

echo "=== 启动服务（uvicorn -> 端口 8000）==="
nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 >> ~/gemini-audio-service.log 2>&1 &
sleep 5

if ps aux | grep -q "[u]vicorn main:app"; then
  echo "✅ 服务已启动"
  echo ""
  echo "=== 健康检查（本机 8000）==="
  sleep 8
  if curl -sf --connect-timeout 10 http://127.0.0.1:8000/health > /dev/null; then
    echo "✅ 健康检查通过: http://127.0.0.1:8000/health"
  else
    echo "⚠️ 健康检查未通过，服务可能仍在初始化，稍后可重试"
  fi
  echo ""
  echo "=== 最新日志 ==="
  tail -30 ~/gemini-audio-service.log | grep -E "Uvicorn|Application startup|启动|ERROR|INFO.*main" || tail -15 ~/gemini-audio-service.log
else
  echo "❌ 服务未启动，最后 50 行日志："
  tail -50 ~/gemini-audio-service.log
  exit 1
fi
SSH_EOF

echo ""
echo "========== 执行完成 =========="
DEPLOY_HOST="${SERVER#*@}"
echo "本机健康检查: curl -s http://${DEPLOY_HOST}:8000/health"
