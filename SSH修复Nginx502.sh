#!/bin/bash
# 通过 SSH 在服务器上自动执行：把 Nginx 的 proxy_pass 从 8001 改为 8000，修复 502
# 使用前请确保本机已配置 SSH 免密
#
# 配置（任选其一）：
#   1. 创建 .deploy.env：DEPLOY_SERVER=admin@47.79.254.213
#   2. 或运行前：export DEPLOY_SERVER=admin@你的服务器
#
# 用法：./SSH修复Nginx502.sh  或  bash SSH修复Nginx502.sh

set -e

LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

if [ -f "$LOCAL_DIR/.deploy.env" ]; then
  set -a
  source "$LOCAL_DIR/.deploy.env"
  set +a
  SERVER="${DEPLOY_SERVER:-$SERVER}"
fi

echo "========== SSH 修复 Nginx 502（proxy_pass 8001 -> 8000）=========="
echo "服务器: $SERVER"
echo ""

ssh "$SERVER" << 'SSH_EOF'
set -e

echo "=== 1. 端口监听 ==="
ss -tlnp 2>/dev/null | grep -E '8000|8001' || true

echo ""
echo "=== 2. 含 8001 的 Nginx 配置 ==="
grep -r "8001\|8000" /etc/nginx/sites-enabled/ /etc/nginx/sites-available/ 2>/dev/null | grep -v "^\s*#" || true

echo ""
echo "=== 3. 修改 proxy_pass 8001 -> 8000 ==="
for f in /etc/nginx/sites-available/gemini-and-api /etc/nginx/sites-available/default /etc/nginx/sites-enabled/*; do
  if [ -f "$f" ] && grep -q "127.0.0.1:8001\|localhost:8001" "$f" 2>/dev/null; then
    sudo sed -i.bak 's|127.0.0.1:8001|127.0.0.1:8000|g; s|localhost:8001|127.0.0.1:8000|g' "$f"
    echo "已修改: $f"
  fi
done

echo ""
echo "=== 4. 测试并重载 Nginx ==="
if sudo nginx -t 2>&1; then
  sudo systemctl reload nginx 2>/dev/null || sudo service nginx reload 2>/dev/null
  echo "✅ Nginx 已重载"
else
  echo "❌ nginx -t 失败，未重载。可执行: sudo nginx -t"
  exit 1
fi

echo ""
echo "=== 5. 验证（本机 curl）==="
sleep 2
if curl -sf --connect-timeout 5 http://127.0.0.1:8000/health > /dev/null; then
  echo "✅ 8000 健康检查通过"
else
  echo "⚠️ 8000 无响应，请确认 uvicorn 在跑: ps aux | grep uvicorn"
fi
SSH_EOF

echo ""
echo "========== 执行完成 =========="
echo "请在客户端重试任务/技能/档案列表；若仍 502，检查 Nginx 实际生效的 server 块。"
echo "本机可测: curl -s http://${SERVER#*@}:8001/api/v1/health 或 :8000/health"