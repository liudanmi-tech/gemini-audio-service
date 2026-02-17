#!/bin/bash
# 修复 RDS 数据库连接导致的登录失败
#
# === 必须先在阿里云 RDS 控制台完成 ===
# 1. 登录 https://rdsnext.console.aliyun.com/
# 2. 选择 PostgreSQL 实例 → 数据安全性 → 白名单 → 添加 47.79.254.213
# 3. 若 RDS 已开启 SSL 且报 "rejected SSL upgrade"：
#    - 数据安全性 → SSL → 下载 CA 证书
#    - 解压得到 PEM 文件，上传到服务器 certs/rds-ca.pem
#    - 执行前设置: export DATABASE_CA_CERT=/home/admin/gemini-audio-service/certs/rds-ca.pem
#
# === 执行 ===
# DATABASE_SSL=true DATABASE_CA_CERT=/path/to/ca.pem ./修复RDS登录问题.sh
# 或: ./修复RDS登录问题.sh

set -e
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"

USE_SSL="${DATABASE_SSL:-true}"
# DATABASE_CA_CERT: 远程服务器上的证书路径；LOCAL_CA_CERT: 本地证书文件，将自动上传
CA_CERT="${DATABASE_CA_CERT:-}"
LOCAL_CA="${LOCAL_CA_CERT:-}"

# 若指定本地证书且存在，上传到服务器并设置远程路径
if [ -n "$LOCAL_CA" ] && [ -f "$LOCAL_CA" ]; then
  echo "上传 CA 证书到服务器..."
  ssh "$SERVER" "mkdir -p ~/gemini-audio-service/certs"
  scp "$LOCAL_CA" "$SERVER:~/gemini-audio-service/certs/rds-ca.pem"
  CA_CERT=$(ssh "$SERVER" 'cd ~/gemini-audio-service && pwd')/certs/rds-ca.pem
fi

echo "========== 修复 RDS 登录 =========="
echo "服务器: $SERVER"
echo "DATABASE_SSL: $USE_SSL"
echo "DATABASE_CA_CERT: ${CA_CERT:-未设置}"
echo ""

# 上传最新 database/connection.py（支持 CA 证书）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/database/connection.py" ]; then
  echo "上传 connection.py..."
  scp "$SCRIPT_DIR/database/connection.py" "$SERVER:~/gemini-audio-service/database/"
fi

ssh "$SERVER" "bash -s" -- << SSH_EOF
set -e
cd ~/gemini-audio-service

# 设置 DATABASE_SSL
if grep -q "^DATABASE_SSL=" .env 2>/dev/null; then
  sed -i "s/^DATABASE_SSL=.*/DATABASE_SSL=$USE_SSL/" .env
else
  echo "DATABASE_SSL=$USE_SSL" >> .env
fi
echo "已设置 DATABASE_SSL=$USE_SSL"

# 设置 DATABASE_CA_CERT（若传入）
if [ -n "$CA_CERT" ]; then
  if grep -q "^DATABASE_CA_CERT=" .env 2>/dev/null; then
    sed -i "s|^DATABASE_CA_CERT=.*|DATABASE_CA_CERT=$CA_CERT|" .env
  else
    echo "DATABASE_CA_CERT=$CA_CERT" >> .env
  fi
  echo "已设置 DATABASE_CA_CERT=$CA_CERT"
fi

# 上传 database/connection.py（含 CA 支持）
# 若需上传，请在本地执行: scp database/connection.py $SERVER:~/gemini-audio-service/database/

# 重启服务
echo "重启服务..."
pkill -f "uvicorn main" 2>/dev/null || true
pkill -f "python.*main" 2>/dev/null || true
sleep 3
nohup venv/bin/python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 20

echo ""
echo "=== 测试登录接口 ==="
SEND=\$(curl -s -X POST "http://localhost:8000/api/v1/auth/send-code" -H "Content-Type: application/json" -d '{"phone":"13800138000"}')
echo "发送验证码: \$SEND"
LOGIN=\$(curl -s -X POST "http://localhost:8000/api/v1/auth/login" -H "Content-Type: application/json" -d '{"phone":"13800138000","code":"123456"}')
if echo "\$LOGIN" | grep -q '"token"'; then
  echo "✅ 登录接口正常"
else
  echo "❌ 登录失败: \$LOGIN"
fi

echo ""
echo "=== 最新日志 ==="
tail -15 ~/gemini-audio-service.log
SSH_EOF

echo ""
echo "========== 完成 =========="
echo "若仍失败：1) 检查白名单 2) 若报 rejected SSL upgrade，下载 RDS CA 证书并设置 DATABASE_CA_CERT"
