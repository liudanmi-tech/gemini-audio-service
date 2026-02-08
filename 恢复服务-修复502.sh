#!/bin/bash
# 欠费恢复或重启后出现 502 时，在本地执行本脚本：SSH 到服务器并重启应用（端口 8000）
# 用法：./恢复服务-修复502.sh

set -e

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 恢复服务（修复 502）=========="
echo "服务器: $SERVER"
echo ""

ssh "$SERVER" << 'EOF'
set -e
cd ~/gemini-audio-service || { echo "❌ 目录不存在"; exit 1; }

echo "=== 1. 当前端口与进程 ==="
ss -tlnp 2>/dev/null | grep -E ':8000|:8001' || echo "  8000/8001 无监听"
ps aux | grep -E "uvicorn|main.py" | grep -v grep || true

echo ""
echo "=== 2. 结束旧进程并启动应用（端口 8000）==="
pkill -f "uvicorn main:app" 2>/dev/null || true
pkill -f "python.*main.py" 2>/dev/null || true
sleep 3

if [ -x "venv/bin/uvicorn" ]; then
  nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 >> ~/gemini-audio-service.log 2>&1 &
else
  nohup python3 main.py >> ~/gemini-audio-service.log 2>&1 &
fi
sleep 5

echo ""
echo "=== 3. 健康检查 ==="
if curl -sf --connect-timeout 5 http://127.0.0.1:8000/health >/dev/null; then
  echo "✅ 应用已启动，端口 8000 正常"
  curl -s http://127.0.0.1:8000/health | head -1
else
  echo "❌ 应用未响应，查看日志:"
  tail -30 ~/gemini-audio-service.log
  exit 1
fi

echo ""
echo "=== 4. 任务列表接口（本机）==="
curl -sf --connect-timeout 5 -o /dev/null -w "  HTTP %{http_code}\n" "http://127.0.0.1:8000/api/v1/tasks/sessions?page=1&page_size=1" -H "Authorization: Bearer test" 2>/dev/null || echo "  需带有效 Token 测试"
EOF

echo ""
echo "========== 完成 =========="
echo "请在客户端重新加载任务列表。若仍 502，确认 Nginx proxy_pass 指向 8000："
echo "  ssh $SERVER 'grep -r proxy_pass /etc/nginx/sites-enabled/ 2>/dev/null | grep 8000'"
echo "本机可测: curl -s http://47.79.254.213/api/v1/health"
echo "（健康检查无认证；任务列表需登录后带 Token 访问）"
