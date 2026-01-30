#!/bin/bash
# 在本机终端执行：SSH 到服务器并执行 Nginx 修复（/secret-channel 代理）
# 用法：chmod +x run_nginx_fix_on_server.sh && ./run_nginx_fix_on_server.sh
# 前提：本机已能免密 ssh admin@47.79.254.213

set -e
cd "$(dirname "$0")"
SERVER="admin@47.79.254.213"

echo "========== 上传修复脚本到服务器 =========="
scp -q scripts/fix_nginx_gemini_proxy.sh "$SERVER:/tmp/fix_nginx_gemini_proxy.sh"

echo "========== 在服务器上执行修复 =========="
ssh "$SERVER" "bash /tmp/fix_nginx_gemini_proxy.sh"

echo ""
echo "========== 完成 =========="
