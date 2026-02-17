#!/bin/bash
# 在服务器上直接执行：修复任务列表/auth 超时
# 用法：SSH 登录后，在服务器上运行: bash 服务器上执行-修复超时.sh

set -e

echo "========== 修复任务列表超时（服务器本机执行）=========="

echo ""
echo "=== 1. Nginx 超时配置 ==="
NGINX_CONF=""
for f in /etc/nginx/sites-available/gemini-and-api /etc/nginx/sites-available/default; do
  if [ -f "$f" ] && grep -q "proxy_pass.*8000" "$f" 2>/dev/null; then
    NGINX_CONF="$f"
    break
  fi
done
[ -z "$NGINX_CONF" ] && NGINX_CONF="/etc/nginx/sites-available/default"

echo "使用: $NGINX_CONF"

if grep -q "proxy_read_timeout 60s\|proxy_connect_timeout 60s\|proxy_send_timeout 60s" "$NGINX_CONF" 2>/dev/null; then
  sudo sed -i.bak 's/proxy_read_timeout 60s/proxy_read_timeout 120s/g; s/proxy_connect_timeout 60s/proxy_connect_timeout 120s/g; s/proxy_send_timeout 60s/proxy_send_timeout 120s/g' "$NGINX_CONF"
  echo "已把 60s 改为 120s"
elif ! grep -q "proxy_read_timeout" "$NGINX_CONF" 2>/dev/null; then
  sudo sed -i '/proxy_pass http:\/\/127.0.0.1:8000;/a\
        proxy_read_timeout 120s;\
        proxy_connect_timeout 120s;\
        proxy_send_timeout 120s;' "$NGINX_CONF"
  echo "已添加 proxy_*_timeout 120s"
else
  echo "当前已有超时配置"
fi

if sudo nginx -t 2>&1; then
  sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null
  echo "✅ Nginx 已重载"
else
  echo "❌ nginx -t 失败"
  exit 1
fi

echo ""
echo "=== 2. 应用状态 ==="
if ss -tlnp 2>/dev/null | grep -q ':8000'; then
  echo "✅ 8000 端口已监听"
else
  echo "启动应用..."
  pkill -f "uvicorn main:app" 2>/dev/null || true
  pkill -f "python.*main.py" 2>/dev/null || true
  sleep 2
  cd ~/gemini-audio-service 2>/dev/null || true
  nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 >> ~/gemini-audio-service.log 2>&1 &
  sleep 5
  echo "已启动，约 20 秒后就绪"
fi

echo ""
echo "=== 3. 健康检查 ==="
sleep 3
if curl -sf --connect-timeout 5 --max-time 10 http://127.0.0.1:8000/health; then
  echo " ✅ 应用正常"
else
  echo "⚠️ 健康检查失败，查看: tail -50 ~/gemini-audio-service.log"
fi

echo ""
echo "========== 完成 =========="
