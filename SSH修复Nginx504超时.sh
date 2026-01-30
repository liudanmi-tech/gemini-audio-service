#!/bin/bash
# 通过 SSH 在服务器上为 /api/ 增加 Nginx 代理超时，修复策略加载 504 Gateway Time-out
# 配置同 SSH修复Nginx502.sh（.deploy.env 或 DEPLOY_SERVER）
# 用法：./SSH修复Nginx504超时.sh  或  bash SSH修复Nginx504超时.sh

set -e

LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

if [ -f "$LOCAL_DIR/.deploy.env" ]; then
  set -a
  source "$LOCAL_DIR/.deploy.env"
  set +a
  SERVER="${DEPLOY_SERVER:-$SERVER}"
fi

echo "========== SSH 修复 Nginx 504 超时（/api/ 代理超时 300s）=========="
echo "服务器: $SERVER"
echo ""

ssh "$SERVER" << 'SSH_EOF'
set -e

NGINX_API_CONF="/etc/nginx/sites-available/gemini-and-api"
if [ ! -f "$NGINX_API_CONF" ]; then
  NGINX_API_CONF="/etc/nginx/sites-available/default"
fi

echo "=== 1. 备份并检查当前配置 ==="
sudo cp -a "$NGINX_API_CONF" "${NGINX_API_CONF}.bak.$(date +%Y%m%d%H%M%S)"
grep -n "proxy_read_timeout\|proxy_connect_timeout\|proxy_send_timeout" "$NGINX_API_CONF" || true

echo ""
echo "=== 2. 将 /api/ 块内的 60s 超时改为 300s（策略生成耗时长）==="
# 若存在 60s，改为 300s（仅改 60s，保留已有的 600s）
if grep -q "proxy_read_timeout 60s\|proxy_connect_timeout 60s\|proxy_send_timeout 60s" "$NGINX_API_CONF" 2>/dev/null; then
  sudo sed -i 's/proxy_read_timeout 60s/proxy_read_timeout 300s/g; s/proxy_connect_timeout 60s/proxy_connect_timeout 300s/g; s/proxy_send_timeout 60s/proxy_send_timeout 300s/g' "$NGINX_API_CONF"
  echo "已把 60s 改为 300s"
else
  echo "未发现 60s，若 /api/ 块尚无超时则添加 300s"
  if ! grep -q "proxy_read_timeout" "$NGINX_API_CONF" 2>/dev/null; then
    sudo sed -i '/proxy_pass http:\/\/127.0.0.1:8000;/a\
        proxy_read_timeout 300s;\
        proxy_connect_timeout 300s;\
        proxy_send_timeout 300s;' "$NGINX_API_CONF"
    echo "已添加：proxy_*_timeout 300s"
  fi
fi

echo ""
echo "=== 3. 测试并重载 Nginx ==="
if sudo nginx -t 2>&1; then
  sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null
  echo "✅ Nginx 已重载"
else
  echo "❌ nginx -t 失败，已回滚"
  sudo cp -a "${NGINX_API_CONF}.bak."* "$NGINX_API_CONF"
  exit 1
fi

echo ""
echo "=== 4. 确认 /api/ 块中的超时已生效 ==="
grep -A6 "location /api" "$NGINX_API_CONF" | head -12 || true
SSH_EOF

echo ""
echo "========== 完成 =========="
echo "请重新在客户端打开任务详情并加载策略；若仍 504，可在服务器上把 300s 改为 600s 后重载 Nginx。"