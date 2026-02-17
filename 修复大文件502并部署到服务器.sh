#!/bin/bash
# 一键修复大文件上传 502 + 上传代码到服务器并重启
# 用法：./修复大文件502并部署到服务器.sh
# 需配置 SSH 免密：ssh admin@47.79.254.213

set -e

LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
REMOTE_DIR="${REMOTE_DIR:-~/gemini-audio-service}"

if [ -f "$LOCAL_DIR/.deploy.env" ]; then
  set -a
  source "$LOCAL_DIR/.deploy.env"
  set +a
  SERVER="${DEPLOY_SERVER:-$SERVER}"
fi

echo "========== 修复大文件 502 + 部署到服务器 =========="
echo "服务器: $SERVER"
echo "远程目录: $REMOTE_DIR"
echo ""

# ========== 1. 修复 Nginx 502（大文件上传超时）==========
echo "=== 1. 修复 Nginx 大文件上传 502 ==="
bash "$LOCAL_DIR/SSH修复Nginx502大文件上传.sh"
echo ""

# ========== 2. 同步代码到服务器 ==========
echo "=== 2. 同步代码到服务器 ==="
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
  echo "❌ rsync 同步失败"
  exit 1
fi
echo "✅ 代码同步完成"
echo ""

# ========== 3. 上传迁移文件 ==========
echo "=== 3. 上传迁移文件 ==="
ssh $SERVER "mkdir -p $REMOTE_DIR/database/migrations"
for f in add_skills_tables.sql alter_confidence_to_float.sql add_sessions_error_message.sql \
  run_add_sessions_error_message.py add_session_audio_and_speaker_mapping.sql \
  run_add_session_audio_and_speaker_mapping.py; do
  [ -f "$LOCAL_DIR/database/migrations/$f" ] && scp -q "$LOCAL_DIR/database/migrations/$f" "$SERVER:$REMOTE_DIR/database/migrations/" 2>/dev/null || true
done
echo ""

# ========== 4. 重启 Python 服务 ==========
echo "=== 4. 重启 Python 服务 ==="
ssh $SERVER << 'SSH_EOF'
cd ~/gemini-audio-service
source venv/bin/activate 2>/dev/null || true

# 执行迁移（若有）
[ -f database/migrations/run_add_sessions_error_message.py ] && python3 database/migrations/run_add_sessions_error_message.py 2>/dev/null || true
[ -f database/migrations/run_add_session_audio_and_speaker_mapping.py ] && python3 database/migrations/run_add_session_audio_and_speaker_mapping.py 2>/dev/null || true

pkill -f "python.*main.py" 2>/dev/null || echo "无旧进程"
sleep 2

nohup python3 main.py >> ~/gemini-audio-service.log 2>&1 &
sleep 5

if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    tail -20 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|技能|ERROR" || tail -10 ~/gemini-audio-service.log
else
    echo "❌ 服务未启动"
    tail -30 ~/gemini-audio-service.log
fi
SSH_EOF

echo ""
echo "========== 部署完成 =========="
echo "请重新尝试上传 20MB+ 录音文件进行验证。"
