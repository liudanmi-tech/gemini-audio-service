#!/bin/bash
# 修复 Nginx 502（大文件上传如 20MB+ 录音）
# 原因：proxy_send_timeout / proxy_read_timeout 过短，或 client_max_body_size 不足
# 用法：./SSH修复Nginx502大文件上传.sh

set -e

LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

if [ -f "$LOCAL_DIR/.deploy.env" ]; then
  set -a
  source "$LOCAL_DIR/.deploy.env"
  set +a
  SERVER="${DEPLOY_SERVER:-$SERVER}"
fi

echo "========== 修复 Nginx 502（大文件上传 20MB+）=========="
echo "服务器: $SERVER"
echo ""

ssh "$SERVER" << 'SSH_EOF'
set -e

# 查找 API 相关配置
CONF=""
for f in /etc/nginx/sites-available/gemini-and-api /etc/nginx/sites-available/default; do
  if [ -f "$f" ] && grep -q "location /api\|proxy_pass.*8000" "$f" 2>/dev/null; then
    CONF="$f"
    break
  fi
done
[ -z "$CONF" ] && CONF="/etc/nginx/sites-available/default"

echo "=== 目标配置文件: $CONF ==="
sudo cp -a "$CONF" "${CONF}.bak.$(date +%Y%m%d%H%M%S)"

# 1. 全局或 server 块：client_max_body_size 100M
if ! grep -q "client_max_body_size 100M" "$CONF"; then
  if grep -q "client_max_body_size" "$CONF"; then
    sudo sed -i 's/client_max_body_size [0-9]*[mMkK]*/client_max_body_size 100M/g' "$CONF"
    echo "✅ 已将 client_max_body_size 改为 100M"
  else
    sudo sed -i '0,/server[[:space:]]*{/s/server[[:space:]]*{/server {\n    client_max_body_size 100M;\n    client_body_buffer_size 128k;/' "$CONF"
    echo "✅ 已添加 client_max_body_size 100M"
  fi
else
  echo "✓ client_max_body_size 100M 已存在"
fi

# 2. 全局替换超时：60s/300s -> 600s（大文件上传必须足够长）
sudo sed -i 's/proxy_read_timeout 60s/proxy_read_timeout 600s/g' "$CONF"
sudo sed -i 's/proxy_read_timeout 300s/proxy_read_timeout 600s/g' "$CONF"
sudo sed -i 's/proxy_connect_timeout 60s/proxy_connect_timeout 600s/g' "$CONF"
sudo sed -i 's/proxy_connect_timeout 300s/proxy_connect_timeout 600s/g' "$CONF"
sudo sed -i 's/proxy_send_timeout 60s/proxy_send_timeout 600s/g' "$CONF"
sudo sed -i 's/proxy_send_timeout 300s/proxy_send_timeout 600s/g' "$CONF"

# 3. 若仍无 proxy_send_timeout 600s，在 proxy_pass 行后添加（针对 /api 或根 location）
if ! grep -q "proxy_send_timeout 600s" "$CONF"; then
  sudo sed -i 's|\(proxy_pass http://127.0.0.1:8000;\)|\1\n        proxy_read_timeout 600s;\n        proxy_connect_timeout 600s;\n        proxy_send_timeout 600s;|' "$CONF"
  echo "✅ 已在 proxy_pass 后添加 600s 超时"
else
  echo "✓ proxy_*_timeout 600s 已存在"
fi

# 4. nginx.conf 全局（备用）
NGINX_MAIN="/etc/nginx/nginx.conf"
if [ -f "$NGINX_MAIN" ] && ! grep -q "client_max_body_size 100M" "$NGINX_MAIN"; then
  if grep -q "client_max_body_size" "$NGINX_MAIN"; then
    sudo sed -i 's/client_max_body_size [0-9]*[mMkK]*/client_max_body_size 100M/g' "$NGINX_MAIN"
  else
    sudo sed -i '/^[[:space:]]*http[[:space:]]*{/a\    client_max_body_size 100M;' "$NGINX_MAIN"
  fi
  echo "✅ nginx.conf 已添加 client_max_body_size 100M"
fi

echo ""
echo "=== 测试并重载 Nginx ==="
if sudo nginx -t 2>&1; then
  sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null
  echo "✅ Nginx 已重载"
else
  echo "❌ nginx -t 失败，请检查配置"
  exit 1
fi

echo ""
echo "=== 当前 /api 相关配置 ==="
grep -A20 "location /api" "$CONF" 2>/dev/null | head -25 || true
SSH_EOF

echo ""
echo "========== 完成 =========="
echo "请重新尝试上传 20MB+ 录音文件。若仍 502，可在服务器执行："
echo "  tail -100 ~/gemini-audio-service.log | grep -E '收到音频|upload|ERROR'"
echo "查看服务端是否收到请求。"
