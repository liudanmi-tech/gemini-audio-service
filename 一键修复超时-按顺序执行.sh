#!/bin/bash
# 按顺序修复任务列表超时问题
# 用法：./一键修复超时-按顺序执行.sh
# 需确保本机可 SSH 到服务器

set -e

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========== 按顺序修复任务列表超时 =========="
echo "服务器: $SERVER"
echo ""

# 步骤 1：上传代码并重启应用
echo ">>> 步骤 1/3：上传 main.py、auth/jwt_handler.py 并重启应用"
scp -o ConnectTimeout=25 "$DIR/main.py" "$SERVER:~/gemini-audio-service/" || { echo "❌ 上传 main.py 失败"; exit 1; }
scp -o ConnectTimeout=25 "$DIR/auth/jwt_handler.py" "$SERVER:~/gemini-audio-service/auth/" || { echo "❌ 上传 jwt_handler.py 失败"; exit 1; }

ssh -o ConnectTimeout=25 "$SERVER" 'cd ~/gemini-audio-service && pkill -f "uvicorn main:app" 2>/dev/null; pkill -f "python.*main.py" 2>/dev/null; sleep 3; nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 >> ~/gemini-audio-service.log 2>&1 &'
echo "已重启应用，等待 25 秒..."
sleep 25

# 验证应用启动
if ssh -o ConnectTimeout=10 "$SERVER" 'curl -sf --max-time 5 http://127.0.0.1:8000/health' 2>/dev/null; then
  echo "✅ 步骤 1 完成：应用已启动"
else
  echo "⚠️ 应用可能仍在启动，继续执行..."
fi

echo ""
echo ">>> 步骤 2/3：添加 sessions 列表索引"
scp -o ConnectTimeout=25 "$DIR/database/migrations/add_sessions_list_index.sql" "$SERVER:~/gemini-audio-service/database/migrations/" 2>/dev/null || true
scp -o ConnectTimeout=25 "$DIR/database/migrations/run_add_sessions_list_index.py" "$SERVER:~/gemini-audio-service/database/migrations/" 2>/dev/null || true

ssh -o ConnectTimeout=25 "$SERVER" 'cd ~/gemini-audio-service && python3 database/migrations/run_add_sessions_list_index.py' 2>/dev/null && echo "✅ 步骤 2 完成：索引已创建" || echo "⚠️ 索引可能已存在或需检查 DB 连接，继续..."

echo ""
echo ">>> 步骤 3/3：修复 Nginx 超时"
ssh -o ConnectTimeout=25 "$SERVER" bash << 'NGINX'
NGINX_CONF="/etc/nginx/sites-available/gemini-and-api"
[ ! -f "$NGINX_CONF" ] && NGINX_CONF="/etc/nginx/sites-available/default"
if grep -q "proxy_read_timeout 60s" "$NGINX_CONF" 2>/dev/null; then
  sudo sed -i.bak 's/proxy_read_timeout 60s/proxy_read_timeout 120s/g; s/proxy_connect_timeout 60s/proxy_connect_timeout 120s/g; s/proxy_send_timeout 60s/proxy_send_timeout 120s/g' "$NGINX_CONF"
  echo "已把 60s 改为 120s"
fi
sudo nginx -t 2>&1 && sudo systemctl reload nginx 2>/dev/null && echo "✅ Nginx 已重载" || echo "⚠️ Nginx 重载失败，请手动检查"
NGINX

echo ""
echo "========== 全部完成 =========="
echo "请重新在 iOS 客户端加载任务列表测试。"
