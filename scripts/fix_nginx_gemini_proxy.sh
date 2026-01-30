#!/bin/bash
# 在服务器上执行：修复 Nginx 配置并启动，使 /secret-channel 代理到 Gemini
# 用法：bash scripts/fix_nginx_gemini_proxy.sh  或  sudo bash fix_nginx_gemini_proxy.sh

set -e
echo "========== 1. 移除冲突的 default 站点 =========="
sudo rm -f /etc/nginx/sites-enabled/default

echo "========== 2. 写入 gemini-proxy 配置 =========="
sudo tee /etc/nginx/sites-available/gemini-proxy > /dev/null << 'ENDOFFILE'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
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
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
ENDOFFILE

echo "========== 3. 启用并检查配置 =========="
sudo ln -sf /etc/nginx/sites-available/gemini-proxy /etc/nginx/sites-enabled/
sudo nginx -t

echo "========== 4. 启动或重载 Nginx =========="
if systemctl is-active --quiet nginx 2>/dev/null; then
    sudo systemctl reload nginx
else
    sudo systemctl start nginx
fi

echo "========== 5. 验证 /secret-channel =========="
curl -s -o /dev/null -w "127.0.0.1/secret-channel => HTTP %{http_code}\n" --connect-timeout 5 http://127.0.0.1/secret-channel/ || true
echo "Done."
