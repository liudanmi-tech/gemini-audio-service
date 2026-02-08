#!/bin/bash
# 仅上传「职场丛林法则」技能 SKILL.md 到服务器并重启服务，使新 Prompt 生效

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 上传职场丛林法则技能到服务器 =========="
echo ""

# 1. 上传 workplace_jungle/SKILL.md
echo "1. 上传 skills/workplace_jungle/SKILL.md ..."
scp skills/workplace_jungle/SKILL.md $SERVER:$REMOTE_DIR/skills/workplace_jungle/
if [ $? -ne 0 ]; then
    echo "❌ 上传 SKILL.md 失败"
    exit 1
fi
echo "✅ SKILL.md 上传成功"
echo ""

# 2. 重启服务（技能在启动时从文件加载，需重启才能读到新内容）
echo "2. 重启服务..."
ssh $SERVER << 'EOF'
cd ~/gemini-audio-service
source venv/bin/activate 2>/dev/null || true

# 停止旧服务
pkill -f "python.*main.py" || echo "没有运行中的服务"
sleep 2

# 启动新服务
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 5

if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    tail -20 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|技能|skill|ERROR" || tail -10 ~/gemini-audio-service.log
else
    echo "❌ 服务启动失败"
    tail -50 ~/gemini-audio-service.log
fi
EOF

echo ""
echo "========== 职场丛林法则技能已更新到服务端 =========="
