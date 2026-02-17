#!/bin/bash
# 部署 main.py 到服务器并重启应用
# 在本机终端执行：bash 部署main并重启.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

echo "========== 部署 main.py 并重启 =========="
echo "服务器: $SERVER"
echo ""

echo "1. 上传 main.py 和 utils/audio_storage.py..."
scp -o ConnectTimeout=25 "$SCRIPT_DIR/main.py" "$SERVER:~/gemini-audio-service/" || {
  echo "❌ main.py 上传失败"
  exit 1
}
scp -o ConnectTimeout=25 "$SCRIPT_DIR/utils/audio_storage.py" "$SERVER:~/gemini-audio-service/utils/" || {
  echo "⚠️ utils/audio_storage.py 上传失败（大文件分片功能不可用），继续..."
}

echo "2. 重启应用..."
ssh -o ConnectTimeout=25 "$SERVER" bash << 'REMOTE'
cd ~/gemini-audio-service
pkill -f "uvicorn main:app" 2>/dev/null || true
sleep 3
nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2 >> ~/gemini-audio-service.log 2>&1 &
sleep 6
if curl -sf --max-time 5 http://127.0.0.1:8000/health >/dev/null; then
  echo "✅ 应用已启动，health OK"
else
  echo "⚠️ 健康检查失败，请查看日志: tail -50 ~/gemini-audio-service.log"
fi
REMOTE

echo ""
echo "========== 部署完成 =========="
