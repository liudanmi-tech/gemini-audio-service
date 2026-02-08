#!/bin/bash
# 在服务器上为 Nginx 增加 client_max_body_size，修复录音上传 413 Request Entity Too Large
# 用法：./SSH修复Nginx413上传大小.sh

set -e

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

echo "========== SSH 修复 Nginx 413（允许上传最大 100MB）=========="
echo "服务器: $SERVER"
echo ""

ssh "$SERVER" << 'SSH_EOF'
set -e

# 0) 在 http 块全局设置 100M，确保 127.0.0.1:80/secret-channel 无论命中哪个 server 都生效
NGINX_MAIN="/etc/nginx/nginx.conf"
if [ -f "$NGINX_MAIN" ]; then
  if grep -q "client_max_body_size" "$NGINX_MAIN"; then
    sudo sed -i 's/client_max_body_size [0-9]*[mMkK]*/client_max_body_size 100M/g' "$NGINX_MAIN"
    echo "已在 nginx.conf 将 client_max_body_size 改为 100M"
  else
    # 在 http { 下一行插入
    sudo sed -i '/^[[:space:]]*http[[:space:]]*{/a\    client_max_body_size 100M;' "$NGINX_MAIN"
    echo "已在 nginx.conf http 块添加 client_max_body_size 100M"
  fi
fi

CONF="/etc/nginx/sites-available/gemini-and-api"
[ -f "$CONF" ] || CONF="/etc/nginx/sites-available/default"

echo "=== 站点配置: $CONF ==="
sudo cp -a "$CONF" "${CONF}.bak.$(date +%Y%m%d%H%M%S)"

# 1) 若已有 client_max_body_size，统一改为 100M
if grep -q "client_max_body_size" "$CONF"; then
  sudo sed -i 's/client_max_body_size [0-9]*[mMkK]*/client_max_body_size 100M/g' "$CONF"
  echo "已把现有 client_max_body_size 改为 100M"
fi

# 2) 确保 location /secret-channel/ 内有 100M（Gemini 上传走这里，413 常出在此）
if grep -q "location /secret-channel" "$CONF"; then
  if ! grep -A 20 "location /secret-channel" "$CONF" | grep -q "client_max_body_size 100M"; then
    sudo sed -i '/location \/secret-channel\/[[:space:]]*{/a\        client_max_body_size 100M;' "$CONF"
    echo "已在 location /secret-channel/ 内添加 client_max_body_size 100M"
  else
    echo "location /secret-channel 已有 client_max_body_size 100M"
  fi
fi

# 3) 若整个文件仍无 100M，在第一个 server { 后插入（对所有 location 生效）
if ! grep -q "client_max_body_size 100M" "$CONF"; then
  if grep -q "location /api/" "$CONF"; then
    sudo sed -i '/location \/api\//,/}/{
      /proxy_pass.*8000;/a\
        client_max_body_size 100M;\
        client_body_buffer_size 128k;
    }' "$CONF"
  fi
  if ! grep -q "client_max_body_size 100M" "$CONF"; then
    sudo sed -i '0,/^[[:space:]]*server[[:space:]]*{/s/^\([[:space:]]*server[[:space:]]*{\)/\1\n    client_max_body_size 100M;\n    client_body_buffer_size 128k;/' "$CONF"
  fi
  echo "已在 server 块添加 client_max_body_size 100M"
fi

echo ""
if sudo nginx -t 2>&1; then
  sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null
  echo "✅ Nginx 已重载，上传限制 100MB"
else
  echo "❌ nginx -t 失败"
  exit 1
fi
SSH_EOF

echo ""
echo "========== 完成，请重新上传录音 =========="
