#!/bin/bash
# 一键部署到 47.79.254.213：同步代码并重启服务
# 使用前请确保本机已配置 SSH 免密登录：ssh admin@47.79.254.213 无需输入密码

set -e
SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "========== 部署到 47.79.254.213 =========="
echo "本地目录: $LOCAL_DIR"
echo "远程目录: $REMOTE_DIR"
echo ""

# 1. 使用 rsync 同步代码（排除不需要的文件）
echo "=== 1. 同步代码到服务器 ==="
rsync -avz --delete \
  --exclude='.git' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='venv' \
  --exclude='.env' \
  --exclude='.cursor' \
  --exclude='.DS_Store' \
  --exclude='Models.swift' \
  --exclude='iOS_*' \
  --exclude='*.xc*' \
  --exclude='*.swift' \
  --exclude='*.md' \
  --exclude='*.sh' \
  --exclude='*.exp' \
  --exclude='*.json' \
  --exclude='*.m4a' \
  --exclude='*.log' \
  --exclude='scripts/' \
  "$LOCAL_DIR/" "$SERVER:$REMOTE_DIR/"

if [ $? -ne 0 ]; then
  echo "❌ rsync 同步失败（若未安装 rsync 或 SSH 未配置免密，请先配置）"
  exit 1
fi
echo "✅ 代码同步完成"
echo ""

# 2. 上传数据库迁移与服务器端部署脚本（rsync 已同步代码，此处确保脚本与迁移在）
echo "=== 2. 上传迁移与脚本 ==="
ssh $SERVER "mkdir -p $REMOTE_DIR/database/migrations"
scp -q "$LOCAL_DIR/database/migrations/add_skills_tables.sql" "$SERVER:$REMOTE_DIR/database/migrations/" 2>/dev/null || true
scp -q "$LOCAL_DIR/database/migrations/alter_confidence_to_float.sql" "$SERVER:$REMOTE_DIR/database/migrations/" 2>/dev/null || true
scp -q "$LOCAL_DIR/database/migrations/add_sessions_error_message.sql" "$SERVER:$REMOTE_DIR/database/migrations/" 2>/dev/null || true
scp -q "$LOCAL_DIR/database/migrations/run_add_sessions_error_message.py" "$SERVER:$REMOTE_DIR/database/migrations/" 2>/dev/null || true
scp -q "$LOCAL_DIR/database/migrations/add_session_audio_and_speaker_mapping.sql" "$SERVER:$REMOTE_DIR/database/migrations/" 2>/dev/null || true
scp -q "$LOCAL_DIR/database/migrations/run_add_session_audio_and_speaker_mapping.py" "$SERVER:$REMOTE_DIR/database/migrations/" 2>/dev/null || true
scp -q "$LOCAL_DIR/服务器上执行_部署并重启.sh" "$SERVER:$REMOTE_DIR/" 2>/dev/null || true
echo ""

# 3. 在服务器上执行迁移并重启服务
echo "=== 3. 迁移与重启服务 ==="
ssh $SERVER << 'SSH_EOF'
cd ~/gemini-audio-service
source venv/bin/activate 2>/dev/null || true

# 执行 sessions.error_message 迁移（若未执行过会添加列）
if [ -f database/migrations/run_add_sessions_error_message.py ]; then
    echo "执行数据库迁移（sessions.error_message）..."
    python3 database/migrations/run_add_sessions_error_message.py || true
fi
# 执行 session_audio 与 speaker_mapping 迁移（声纹方案）
if [ -f database/migrations/run_add_session_audio_and_speaker_mapping.py ]; then
    echo "执行数据库迁移（session_audio + speaker_mapping）..."
    python3 database/migrations/run_add_session_audio_and_speaker_mapping.py || true
fi

# 停止旧服务
pkill -f "python.*main.py" 2>/dev/null || echo "没有运行中的服务"
sleep 2

# 启动新服务
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 5

# 检查服务
if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    echo ""
    echo "=== 最新日志 ==="
    tail -25 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|技能|ERROR|Request|Response" || tail -15 ~/gemini-audio-service.log
else
    echo "❌ 服务未启动，查看错误:"
    tail -50 ~/gemini-audio-service.log
fi
SSH_EOF

echo ""
echo "========== 部署完成 =========="
echo "健康检查: curl -s http://47.79.254.213:8001/health"
