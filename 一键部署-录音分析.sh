#!/bin/bash
# 一键部署：上传代码到服务器，修复 Nginx 代理，重启应用
# 在本地项目根目录执行：bash 一键部署-录音分析.sh
# 服务器需已配置 SSH（如 admin@47.79.254.213）

set -e
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
REMOTE_DIR="${REMOTE_DIR:-~/gemini-audio-service}"

echo "========== 1. 上传代码到服务器 =========="
scp main.py "$SERVER:$REMOTE_DIR/"
scp -r scripts "$SERVER:$REMOTE_DIR/" 2>/dev/null || true

echo ""
echo "========== 2. 在服务器上：修复 Nginx 并重启应用 =========="
ssh "$SERVER" bash -s << 'SSH_EOF'
set -e
cd ~/gemini-audio-service

# 2.1 使用独立端口 8080 提供 /secret-channel（仅写 conf.d，避免与 sites-enabled 重复导致 8080 冲突）
echo "--- 配置 Nginx：8080 端口 /secret-channel -> Gemini ---"
sudo rm -f /etc/nginx/sites-enabled/gemini-proxy-8080 /etc/nginx/sites-available/gemini-proxy-8080 2>/dev/null || true
sudo tee /etc/nginx/conf.d/gemini-proxy-8080.conf > /dev/null << 'NGINX'
server {
    listen 8080;
    listen [::]:8080;
    server_name _;

    location /secret-channel/ {
        rewrite ^/secret-channel/(.*) /$1 break;
        proxy_pass https://generativelanguage.googleapis.com;
        proxy_set_header Host generativelanguage.googleapis.com;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_ssl_server_name on;
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
        client_max_body_size 100M;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    location / {
        return 404;
    }
}
NGINX
sudo nginx -t && (sudo systemctl reload nginx 2>/dev/null || sudo systemctl start nginx)

# 2.2 确保 .env 中代理走 8080（应用与 Nginx 同机用 127.0.0.1:8080）
if [ -f .env ]; then
  if grep -q '^PROXY_URL_RAW=' .env; then
    sed -i.bak 's|^PROXY_URL_RAW=.*|PROXY_URL_RAW=http://127.0.0.1:8080/secret-channel|' .env
  else
    echo 'PROXY_URL_RAW=http://127.0.0.1:8080/secret-channel' >> .env
  fi
else
  echo 'PROXY_URL_RAW=http://127.0.0.1:8080/secret-channel' >> .env
fi

# 2.3 重启 Python 应用
echo "--- 重启应用 ---"
source venv/bin/activate 2>/dev/null || true
pkill -f 'python.*main.py' 2>/dev/null || true
sleep 2
nohup python3 main.py >> ~/gemini-audio-service.log 2>&1 &
sleep 3
ps aux | grep '[p]ython.*main.py' || true
echo "--- 验证 /secret-channel（8080）---"
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://127.0.0.1:8080/secret-channel/ 2>/dev/null || echo "ERR")
CODE2=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://127.0.0.1:8080/secret-channel/v1beta/models" 2>/dev/null || echo "ERR")
if [ "$CODE" = "ERR" ]; then
  echo "127.0.0.1:8080 无法连接（请确认 Nginx 已 include conf.d）"
  echo "可手动检查: ls /etc/nginx/conf.d/ && ss -tlnp | grep 8080"
else
  echo "127.0.0.1:8080/secret-channel/ => HTTP $CODE"
  echo "127.0.0.1:8080/secret-channel/v1beta/models => HTTP $CODE2"
  if [ "$CODE2" = "400" ] || [ "$CODE2" = "401" ] || [ "$CODE2" = "403" ]; then
    echo "代理已通（Google 返回 $CODE2 表示请求已到达 Gemini，缺/错 API Key 会报 4xx）。"
  elif [ "$CODE" = "404" ] || [ "$CODE2" = "404" ]; then
    echo "（404 多为 Google 对根路径/部分路径的响应，代理可能已通，可试录音分析。）"
  fi
fi
SSH_EOF

echo ""
echo "========== 部署完成 =========="
echo "Gemini 代理已用 8080 端口（/secret-channel），不再占用 80，避免 Nginx 冲突。"
echo "若录音分析仍报「上传文件失败… string indices」，请查看：部署步骤-录音分析.md"
