#!/bin/bash
# 一键自动部署：同步代码到服务器 → 执行迁移 → 重启服务 → 健康检查
# 使用前请确保本机已配置 SSH 免密：ssh admin@服务器 无需输入密码
#
# 可选配置（在运行前 export，或创建 .deploy.env 并 source）：
#   export DEPLOY_SERVER="admin@47.79.254.213"
#   export DEPLOY_REMOTE_DIR="~/gemini-audio-service"
#   export DEPLOY_HOST="47.79.254.213"   # 健康检查用，默认从 DEPLOY_SERVER 解析
#
# 用法：./自动部署.sh  或  bash 自动部署.sh

set -e

# 配置：可通过环境变量覆盖
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-~/gemini-audio-service}"
DEPLOY_HOST="${DEPLOY_HOST:-${SERVER#*@}}"   # 默认从 admin@47.79.254.213 取 47.79.254.213
HEALTH_URL="http://${DEPLOY_HOST}:8001/health"
LOCAL_DIR="$(cd "$(dirname "$0")" && pwd)"

# 若存在 .deploy.env 则加载（不要提交敏感信息到 git）
if [ -f "$LOCAL_DIR/.deploy.env" ]; then
  set -a
  source "$LOCAL_DIR/.deploy.env"
  set +a
  SERVER="${DEPLOY_SERVER:-$SERVER}"
  REMOTE_DIR="${DEPLOY_REMOTE_DIR:-$REMOTE_DIR}"
  DEPLOY_HOST="${DEPLOY_HOST:-${SERVER#*@}}"
  HEALTH_URL="http://${DEPLOY_HOST}:8001/health"
fi

echo "========== 自动部署 =========="
echo "服务器: $SERVER"
echo "远程目录: $REMOTE_DIR"
echo "本地目录: $LOCAL_DIR"
echo ""

# 1. rsync 同步代码（保护服务器上的 logs、backup_* 不被 --delete 删除）
echo "=== 1. 同步代码到服务器 ==="
rsync -avz --delete \
  --filter='P logs/' \
  --filter='P backup_*/' \
  --exclude='.git' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='venv' \
  --exclude='.venv' \
  --exclude='node_modules' \
  --exclude='data/' \
  --exclude='logs/' \
  --exclude='backup_*/' \
  --exclude='.env' \
  --exclude='.cursor' \
  --exclude='.DS_Store' \
  --exclude='Models.swift' \
  --exclude='iOS_*' \
  --exclude='*.xc*' \
  --exclude='*.swift' \
  --include='skills/' \
  --include='skills/**/' \
  --include='skills/**/*.md' \
  --exclude='*.md' \
  --exclude='*.sh' \
  --exclude='*.exp' \
  --exclude='*.json' \
  --exclude='*.m4a' \
  --exclude='*.log' \
  --exclude='scripts/' \
  "$LOCAL_DIR/" "$SERVER:$REMOTE_DIR/"

if [ $? -ne 0 ]; then
  echo "❌ rsync 失败（请检查 SSH 免密与 rsync 是否安装）"
  exit 1
fi
echo "✅ 代码同步完成"
echo ""

# 2. 上传迁移、技能 SKILL.md 与服务器端脚本（因被 rsync 排除）
echo "=== 2. 上传迁移、技能与脚本 ==="
ssh "$SERVER" "mkdir -p $REMOTE_DIR/database/migrations"
for f in \
  database/migrations/add_skills_tables.sql \
  database/migrations/alter_confidence_to_float.sql \
  database/migrations/add_sessions_error_message.sql \
  database/migrations/run_add_sessions_error_message.py \
  database/migrations/add_session_audio_and_speaker_mapping.sql \
  database/migrations/run_add_session_audio_and_speaker_mapping.py \
  database/migrations/add_skills_prompt_template.sql \
  database/migrations/run_add_skills_prompt_template.py \
  database/migrations/add_performance_indexes.sql \
  ; do
  [ -f "$LOCAL_DIR/$f" ] && scp -q "$LOCAL_DIR/$f" "$SERVER:$REMOTE_DIR/$f" 2>/dev/null || true
done
# 用 rsync 同步整个 skills 目录（仅 .md 与目录；明确包含子目录下的 *.md）
if [ -d "$LOCAL_DIR/skills" ]; then
  rsync -avz --exclude='__pycache__' --include='*/' --include='*.md' --include='*/*.md' --exclude='*' "$LOCAL_DIR/skills/" "$SERVER:$REMOTE_DIR/skills/"
  # 兜底：显式 scp 每个 SKILL.md，避免 rsync 规则导致未同步
  for d in brainstorm workplace_jungle education_communication family_relationship; do
    if [ -f "$LOCAL_DIR/skills/$d/SKILL.md" ]; then
      ssh -q "$SERVER" "mkdir -p $REMOTE_DIR/skills/$d"
      scp -q "$LOCAL_DIR/skills/$d/SKILL.md" "$SERVER:$REMOTE_DIR/skills/$d/SKILL.md" 2>/dev/null || true
    fi
  done
fi
[ -f "$LOCAL_DIR/服务器上执行_部署并重启.sh" ] && scp -q "$LOCAL_DIR/服务器上执行_部署并重启.sh" "$SERVER:$REMOTE_DIR/" 2>/dev/null || true
echo "✅ 迁移、技能与脚本上传完成"
echo ""

# 3. 在服务器上执行迁移并重启
echo "=== 3. 迁移与重启服务 ==="
ssh "$SERVER" << SSH_EOF
cd $REMOTE_DIR
source venv/bin/activate 2>/dev/null || true

# 清除 skills 缓存，确保使用最新 loader.py 和 SKILL.md 解析逻辑
rm -rf skills/__pycache__

if [ -f database/migrations/run_add_sessions_error_message.py ]; then
  echo "执行迁移（sessions.error_message）..."
  python3 database/migrations/run_add_sessions_error_message.py || true
fi
if [ -f database/migrations/run_add_session_audio_and_speaker_mapping.py ]; then
  echo "执行迁移（session_audio + speaker_mapping）..."
  python3 database/migrations/run_add_session_audio_and_speaker_mapping.py || true
fi
if [ -f database/migrations/run_add_skills_prompt_template.py ]; then
  echo "执行迁移（skills.prompt_template）..."
  python3 database/migrations/run_add_skills_prompt_template.py || true
fi

echo "停止旧服务..."
pkill -f "python.*main.py" 2>/dev/null || echo "没有运行中的服务"
sleep 2

echo "启动新服务..."
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
# 应用启动约需 20 秒（数据库+技能初始化），多等几秒再看日志和健康检查
sleep 22

if ps aux | grep -q "[p]ython.*main.py"; then
  echo "✅ 服务已启动"
  echo ""
  echo "=== 最新日志（新进程启动）==="
  (tail -60 ~/gemini-audio-service.log | grep -E "Uvicorn|Application startup|启动|技能|声纹|ERROR|INFO.*main" | tail -20) || tail -20 ~/gemini-audio-service.log
else
  echo "❌ 服务未启动"
  tail -50 ~/gemini-audio-service.log
  exit 1
fi
SSH_EOF

echo ""
echo "=== 4. 健康检查 ==="
sleep 2
if curl -sf --connect-timeout 10 "$HEALTH_URL" > /dev/null 2>&1; then
  echo "✅ 健康检查通过: $HEALTH_URL"
else
  echo "等待 8 秒后重试..."
  sleep 8
  if curl -sf --connect-timeout 10 "$HEALTH_URL" > /dev/null 2>&1; then
    echo "✅ 健康检查通过: $HEALTH_URL"
  else
    echo "⚠️ 健康检查未通过: $HEALTH_URL"
    echo "   若服务在服务器上正常，多为本机到服务器 8001 端口未放行，可在服务器上执行: curl -s localhost:8001/health"
  fi
fi

echo ""
echo "========== 部署完成 =========="
