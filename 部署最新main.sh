#!/bin/bash
# 仅上传最新 main.py 到服务器并自动重启服务（用于声纹降级等 main 单文件更新）
# 使用前请确保本机已配置 SSH 免密：ssh admin@服务器 无需输入密码
#
# 可选：创建 .deploy.env 设置 DEPLOY_SERVER、DEPLOY_REMOTE_DIR、DEPLOY_HOST
# 用法：./部署最新main.sh  或  bash 部署最新main.sh

set -e

LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-~/gemini-audio-service}"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
DEPLOY_HOST="${DEPLOY_HOST:-${SERVER#*@}}"
# 应用可能监听 8000（Nginx 代理）或 8001，两端口都试
HEALTH_URL_8000="http://${DEPLOY_HOST}:8000/health"
HEALTH_URL_8001="http://${DEPLOY_HOST}:8001/health"

if [ -f "$LOCAL_DIR/.deploy.env" ]; then
  set -a
  source "$LOCAL_DIR/.deploy.env"
  set +a
  SERVER="${DEPLOY_SERVER:-$SERVER}"
  REMOTE_DIR="${DEPLOY_REMOTE_DIR:-$REMOTE_DIR}"
  DEPLOY_HOST="${DEPLOY_HOST:-${SERVER#*@}}"
  HEALTH_URL_8000="http://${DEPLOY_HOST}:8000/health"
  HEALTH_URL_8001="http://${DEPLOY_HOST}:8001/health"
fi

echo "========== 部署最新 main.py =========="
echo "服务器: $SERVER"
echo "远程目录: $REMOTE_DIR"
echo ""

echo "=== 1. 上传 main.py ==="
scp -q "$LOCAL_DIR/main.py" "$SERVER:$REMOTE_DIR/main.py"
if [ $? -ne 0 ]; then
  echo "❌ 上传失败（请检查 SSH 免密与网络）"
  exit 1
fi
echo "✅ main.py 上传成功"
echo ""

echo "=== 2. 重启服务 ==="
ssh "$SERVER" << SSH_EOF
set -e
cd $REMOTE_DIR
source venv/bin/activate 2>/dev/null || true

echo "停止旧服务..."
pkill -f "python.*main.py" 2>/dev/null || echo "没有运行中的服务"
pkill -f "uvicorn main:app" 2>/dev/null || true
sleep 2

echo "启动新服务..."
nohup python3 main.py >> ~/gemini-audio-service.log 2>&1 &
sleep 22

if ps aux | grep -q "[p]ython.*main.py"; then
  echo "✅ 服务已启动"
  echo ""
  echo "=== 最新日志 ==="
  (tail -80 ~/gemini-audio-service.log | grep -E "Uvicorn|Application startup|启动|声纹|ERROR|INFO.*main" | tail -25) || tail -25 ~/gemini-audio-service.log
else
  echo "❌ 服务未启动，最后 50 行日志："
  tail -50 ~/gemini-audio-service.log
  exit 1
fi
SSH_EOF

echo ""
echo "=== 3. 健康检查 ==="
sleep 2
HEALTH_OK=0
for url in "$HEALTH_URL_8000" "$HEALTH_URL_8001"; do
  if curl -sf --connect-timeout 10 "$url" > /dev/null 2>&1; then
    echo "✅ 健康检查通过: $url"
    HEALTH_OK=1
    break
  fi
done
if [ "$HEALTH_OK" -eq 0 ]; then
  echo "等待 8 秒后重试..."
  sleep 8
  for url in "$HEALTH_URL_8000" "$HEALTH_URL_8001"; do
    if curl -sf --connect-timeout 10 "$url" > /dev/null 2>&1; then
      echo "✅ 健康检查通过: $url"
      HEALTH_OK=1
      break
    fi
  done
fi
if [ "$HEALTH_OK" -eq 0 ]; then
  echo "⚠️ 本机无法访问健康检查（可能防火墙未放行 8000/8001）"
  echo "   在服务器上可执行: curl -s localhost:8000/health 或 curl -s localhost:8001/health"
fi

echo ""
echo "========== 部署完成 =========="
echo "多人对话声纹降级逻辑已生效，新任务将写入占位 speaker_mapping。"
