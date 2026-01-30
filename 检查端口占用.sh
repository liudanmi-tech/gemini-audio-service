#!/bin/bash
# 在服务器上执行：检查 8000/8001 端口占用及 uvicorn 进程，便于排查 502
# 用法：在服务器上 cd ~/gemini-audio-service && bash 检查端口占用.sh
# 或：ssh admin@服务器 "cd ~/gemini-audio-service && bash 检查端口占用.sh"

echo "========== 端口监听 =========="
echo "8000 端口："
ss -tlnp 2>/dev/null | grep -E ":8000|:8001" || netstat -tlnp 2>/dev/null | grep -E "8000|8001" || true
if command -v lsof >/dev/null 2>&1; then
  lsof -i :8000 2>/dev/null || true
  echo "8001 端口："
  lsof -i :8001 2>/dev/null || true
fi

echo ""
echo "========== uvicorn / main.py 进程 =========="
ps aux | grep -E "uvicorn|main:app|main.py" | grep -v grep

echo ""
echo "========== 建议 =========="
echo "1. 若 8000 无监听或不是 uvicorn -> 启动: nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 >> ~/gemini-audio-service.log 2>&1 &"
echo "2. 若 Nginx 反代到 8001 而当前只起 8000 -> 要么改 Nginx 为 8000，要么起: python3 main.py (默认 8001)"
echo "3. 若端口被其他进程占用 -> 先 pkill 该进程再按上面启动"
