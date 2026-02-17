#!/bin/bash
# 修复任务列表 / auth 接口超时
# 1. 增加 Nginx proxy 超时
# 2. 确保 sessions 列表索引存在（加速查询）
# 3. 重启应用（如有需要）
# 用法：./修复任务列表超时.sh

set -e

SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

echo "========== 修复任务列表超时 =========="
echo "服务器: $SERVER"
echo ""

ssh -o ConnectTimeout=20 "$SERVER" bash << 'REMOTE'
set -e

echo "=== 1. 检查 Nginx 配置与超时 ==="
NGINX_CONF=""
for f in /etc/nginx/sites-available/gemini-and-api /etc/nginx/sites-available/default; do
  if [ -f "$f" ] && grep -q "proxy_pass.*8000" "$f" 2>/dev/null; then
    NGINX_CONF="$f"
    break
  fi
done
[ -z "$NGINX_CONF" ] && NGINX_CONF="/etc/nginx/sites-available/default"

echo "使用配置: $NGINX_CONF"
grep -E "proxy_(read|connect|send)_timeout" "$NGINX_CONF" 2>/dev/null || echo "  当前无 proxy 超时配置"

echo ""
echo "=== 2. 增加 Nginx 超时（60s -> 120s）==="
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
  echo "当前已有超时配置，未修改"
fi

if sudo nginx -t 2>&1; then
  sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null
  echo "✅ Nginx 已重载"
else
  echo "⚠️ nginx -t 失败，恢复备份"
  sudo cp -a "${NGINX_CONF}.bak" "$NGINX_CONF" 2>/dev/null || true
fi

echo ""
echo "=== 3. 确保 sessions 列表索引存在（加速分页查询）==="
cd ~/gemini-audio-service 2>/dev/null || true
if [ -f database/migrations/add_sessions_list_index.sql ]; then
  # 需要 DB 连接信息，这里仅提示
  echo "索引迁移脚本: database/migrations/add_sessions_list_index.sql"
  echo "若列表仍慢，可在服务器执行: psql -f database/migrations/add_sessions_list_index.sql"
fi

echo ""
echo "=== 4. 检查应用状态 ==="
if ss -tlnp 2>/dev/null | grep -q ':8000'; then
  echo "✅ 8000 端口有监听"
  curl -sf --connect-timeout 5 --max-time 10 http://127.0.0.1:8000/health && echo " 健康检查 OK" || echo " 健康检查失败"
else
  echo "⚠️ 8000 无监听，尝试启动..."
  pkill -f "uvicorn main:app" 2>/dev/null || true
  pkill -f "python.*main.py" 2>/dev/null || true
  sleep 2
  nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 >> ~/gemini-audio-service.log 2>&1 &
  sleep 5
  echo "已启动，等待约 20 秒后应用就绪"
fi

echo ""
echo "=== 5. 本机快速测试（需有效 Token）==="
curl -sf --connect-timeout 5 --max-time 15 "http://127.0.0.1:8000/api/v1/tasks/sessions?page=1&page_size=5" \
  -H "Authorization: Bearer test" -o /dev/null -w "任务列表: HTTP %{http_code} 耗时 %{time_total}s\n" 2>/dev/null || echo "  需带有效 JWT 测试"
REMOTE

echo ""
echo "========== 完成 =========="
echo "若仍超时，可能原因："
echo "  1. 网络：手机与服务器间延迟高（可尝试切换 Wi-Fi/4G）"
echo "  2. 数据库：RDS 连接慢，检查安全组与白名单"
echo "  3. 应用：查看日志 tail -100 ~/gemini-audio-service.log"
echo ""
echo "本机可测: curl -s -o /dev/null -w '%{http_code} %{time_total}s' --max-time 30 http://47.79.254.213/health"
