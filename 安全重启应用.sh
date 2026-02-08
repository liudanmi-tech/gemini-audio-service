#!/bin/bash
# 安全重启 FastAPI 应用：先结束所有占用 8000 的进程，再只起一个实例，避免「端口被占用」
# 在服务器上执行：cd ~/gemini-audio-service && bash 安全重启应用.sh
# 或本地 SSH 执行：ssh admin@47.79.254.213 "cd ~/gemini-audio-service && bash 安全重启应用.sh"

set -e

APP_PORT="${UVICORN_PORT:-8000}"
LOG_FILE="${LOG_FILE:-$HOME/gemini-audio-service.log}"
# 若在项目目录下，用项目路径
if [ -d "$(dirname "$0")/venv" ]; then
  cd "$(dirname "$0")"
  VENV="venv/bin"
else
  VENV="${VENV:-venv/bin}"
fi

echo "========== 安全重启应用（端口 $APP_PORT）=========="

# 1. 结束所有可能占用端口的进程（避免重复启动导致 Address already in use）
echo "1. 结束旧进程..."
pkill -f "uvicorn main:app" 2>/dev/null || true
pkill -f "python.*main.py"  2>/dev/null || true
pkill -f "python3 main.py"  2>/dev/null || true
sleep 3

# 2. 确认端口已释放（可选，便于排查）
if command -v ss >/dev/null 2>&1; then
  if ss -tlnp 2>/dev/null | grep -q ":$APP_PORT "; then
    echo "⚠️ 端口 $APP_PORT 仍被占用，尝试按端口结束进程..."
    PID=$(ss -tlnp 2>/dev/null | grep ":$APP_PORT " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | head -1)
    if [ -n "$PID" ]; then
      kill -9 "$PID" 2>/dev/null || true
      sleep 2
    fi
  fi
fi

# 3. 只启动一个实例（优先 uvicorn 与 systemd 一致，端口由环境变量控制）
echo "2. 启动应用（端口 $APP_PORT）..."
if [ -x "$VENV/uvicorn" ]; then
  nohup "$VENV/uvicorn" main:app --host 0.0.0.0 --port "$APP_PORT" >> "$LOG_FILE" 2>&1 &
else
  nohup python3 main.py >> "$LOG_FILE" 2>&1 &
fi

sleep 4

# 4. 健康检查
if curl -sf --connect-timeout 5 "http://127.0.0.1:$APP_PORT/health" >/dev/null; then
  echo "✅ 应用已启动，端口 $APP_PORT 健康检查通过"
else
  echo "❌ 健康检查失败，请查看日志: tail -50 $LOG_FILE"
  exit 1
fi

echo "========== 完成 =========="
