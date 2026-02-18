#!/bin/bash
# 部署「宫崎骏风格 + 档案照片参考」到服务器
# 需上传：main.py、skills/executor.py、4 个 SKILL.md
# 技能在启动时从文件加载，重启后生效
# 用法：bash 部署宫崎骏风格和档案照片参考.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER="${DEPLOY_SERVER:-admin@47.79.254.213}"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-~/gemini-audio-service}"

echo "========== 部署宫崎骏风格 + 档案照片参考 =========="
echo "服务器: $SERVER"
echo "远程目录: $REMOTE_DIR"
echo ""

echo "1. 上传 main.py、api/profiles.py（含档案照片参考、OSS 直接读取）..."
scp -o ConnectTimeout=25 "$SCRIPT_DIR/main.py" "$SERVER:$REMOTE_DIR/" || { echo "❌ main.py 上传失败"; exit 1; }
scp -o ConnectTimeout=25 "$SCRIPT_DIR/api/profiles.py" "$SERVER:$REMOTE_DIR/api/" || { echo "❌ api/profiles.py 上传失败"; exit 1; }

echo "2. 上传 skills/executor.py、skills/loader.py..."
scp -o ConnectTimeout=25 "$SCRIPT_DIR/skills/executor.py" "$SERVER:$REMOTE_DIR/skills/" || { echo "❌ executor.py 上传失败"; exit 1; }
scp -o ConnectTimeout=25 "$SCRIPT_DIR/skills/loader.py" "$SERVER:$REMOTE_DIR/skills/" || { echo "❌ loader.py 上传失败"; exit 1; }

echo "3. 上传 4 个技能 SKILL.md（宫崎骏风格 prompt）..."
for skill_dir in workplace_jungle family_relationship education_communication brainstorm; do
  scp -o ConnectTimeout=25 "$SCRIPT_DIR/skills/$skill_dir/SKILL.md" "$SERVER:$REMOTE_DIR/skills/$skill_dir/" || { echo "❌ $skill_dir/SKILL.md 上传失败"; exit 1; }
  echo "   ✅ $skill_dir/SKILL.md"
done

echo ""
echo "4. 重启服务（技能在启动时从文件加载）..."
ssh -o ConnectTimeout=25 "$SERVER" bash << REMOTE
cd $REMOTE_DIR
source venv/bin/activate 2>/dev/null || true

pkill -f "uvicorn main:app" 2>/dev/null || true
pkill -f "python.*main.py" 2>/dev/null || true
sleep 3

nohup venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 2 >> ~/gemini-audio-service.log 2>&1 &
sleep 6

if curl -sf --max-time 5 http://127.0.0.1:8000/health >/dev/null; then
  echo "✅ 应用已启动，health OK"
  echo ""
  echo "最新日志（技能初始化）："
  tail -30 ~/gemini-audio-service.log | grep -E "技能|skill|宫崎骏|启动|ERROR" || tail -10 ~/gemini-audio-service.log
else
  echo "⚠️ 健康检查失败，请查看: tail -50 ~/gemini-audio-service.log"
fi
REMOTE

echo ""
echo "========== 部署完成 =========="
echo ""
echo "⚠️ 注意：已存在的 session（如 a85878d1）的策略分析是部署前完成的，"
echo "   图片仍为旧风格。新上传并分析的录音将使用宫崎骏风格。"
echo "   若需对旧 session 重新生成图片，需要重新触发策略分析（如有该接口）。"
