#!/bin/bash
# 修复记忆 embedding 维度不匹配：上传 memory_service、清除缓存、重启服务
#
# 用法（在项目根目录执行）：
#   ./修复记忆维度并重启.sh
# 或：
#   bash 修复记忆维度并重启.sh
#
# 需提前配置 SSH 免密：ssh admin@47.79.254.213 无需输入密码

set -e
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-~/gemini-audio-service}"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========== 修复记忆维度并重启 =========="
echo "服务器: $SERVER"
echo ""

echo "=== 1. 上传 memory_service.py ==="
scp -q "$LOCAL_DIR/services/memory_service.py" "$SERVER:$REMOTE_DIR/services/"
echo "✅ 上传完成"
echo ""

echo "=== 2. 清除缓存并重启服务 ==="
ssh "$SERVER" << 'SSH_EOF'
cd ~/gemini-audio-service
source venv/bin/activate 2>/dev/null || true

# 检查 .env 是否覆盖了 GEMINI_EMBEDDING_DIM（若为 768 会导致维度不匹配）
if grep -q "GEMINI_EMBEDDING_DIM" .env 2>/dev/null; then
  dim=$(grep "GEMINI_EMBEDDING_DIM" .env | cut -d= -f2)
  if [ "$dim" = "768" ]; then
    echo "⚠️ .env 中 GEMINI_EMBEDDING_DIM=768，应与 Qdrant 集合一致(1536)。建议改为 1536 或删除该行。"
  fi
fi

# 清除 services 与 mem0 相关缓存，强制重新加载
rm -rf services/__pycache__
rm -f services/*.pyc
echo "✅ 已清除 services 缓存"

# 停止旧服务（包含 uvicorn main:app 和 python main.py）
echo "停止旧服务..."
pkill -f "uvicorn main" 2>/dev/null || true
pkill -f "python.*main.py" 2>/dev/null || true
pkill -f "python.*main:app" 2>/dev/null || true
sleep 3

# 启动新服务
echo "启动新服务..."
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 15

if ps aux | grep -q "[p]ython.*main.py"; then
  echo "✅ 服务已启动"
  echo ""
  echo "=== 最新日志（Mem0 初始化）==="
  tail -100 ~/gemini-audio-service.log | grep -E "Mem0|embedding_dims|记忆" || tail -20 ~/gemini-audio-service.log
else
  echo "❌ 服务启动失败"
  tail -50 ~/gemini-audio-service.log
  exit 1
fi
SSH_EOF

echo ""
echo "========== 完成 =========="
echo "请用新 session 测试记忆写入是否成功。"
