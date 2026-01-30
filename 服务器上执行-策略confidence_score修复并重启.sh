#!/bin/bash
# 在服务器上执行：修复 strategy_analysis.scene_confidence / skill_executions.confidence_score 类型，并重启应用
# 用法：在服务器上 cd ~/gemini-audio-service && bash 服务器上执行-策略confidence_score修复并重启.sh

set -e

cd "$(dirname "$0")"
echo "========== 策略 confidence_score 修复并重启 =========="
echo "当前目录: $(pwd)"
echo ""

if [ -d "venv" ]; then
  source venv/bin/activate
  echo "已激活 venv"
else
  echo "未找到 venv，使用系统 python3"
fi
echo ""

echo "=== 1. 执行迁移（json -> jsonb / confidence_score -> double precision）==="
python3 database/migrations/run_fix_json_to_jsonb.py
echo ""

echo "=== 2. 检查列类型（确认）==="
python3 database/migrations/check_json_columns.py 2>/dev/null || true
echo ""

echo "=== 3. 重启应用 ==="
pkill -f "uvicorn main:app" 2>/dev/null || true
pkill -f "python.*main.py" 2>/dev/null || true
sleep 2
nohup uvicorn main:app --host 0.0.0.0 --port 8000 >> ~/gemini-audio-service.log 2>&1 &
sleep 3
if ps aux | grep -q "[u]vicorn main:app"; then
  echo "✅ 应用已重启（端口 8000）"
  curl -sf --connect-timeout 5 http://127.0.0.1:8000/health && echo "" || true
else
  echo "⚠️ 请检查进程：ps aux | grep uvicorn"
fi
echo ""
echo "========== 完成 =========="
