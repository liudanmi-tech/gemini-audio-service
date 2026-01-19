#!/bin/bash
# 更新服务器代码并重启服务

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 更新服务器代码 =========="

# 1. 上传 main.py
echo "1. 上传 main.py..."
scp main.py $SERVER:$REMOTE_DIR/

# 2. 上传 api/skills.py
echo "2. 上传 api/skills.py..."
ssh $SERVER "mkdir -p $REMOTE_DIR/api"
scp api/skills.py $SERVER:$REMOTE_DIR/api/

# 3. 上传 skills 模块
echo "3. 上传 skills 模块..."
ssh $SERVER "mkdir -p $REMOTE_DIR/skills"
scp skills/__init__.py $SERVER:$REMOTE_DIR/skills/
scp skills/loader.py $SERVER:$REMOTE_DIR/skills/
scp skills/registry.py $SERVER:$REMOTE_DIR/skills/
scp skills/router.py $SERVER:$REMOTE_DIR/skills/
scp skills/executor.py $SERVER:$REMOTE_DIR/skills/
scp skills/composer.py $SERVER:$REMOTE_DIR/skills/

# 4. 上传技能文件
echo "4. 上传技能文件..."
ssh $SERVER "mkdir -p $REMOTE_DIR/skills/workplace_jungle"
ssh $SERVER "mkdir -p $REMOTE_DIR/skills/family_relationship"
ssh $SERVER "mkdir -p $REMOTE_DIR/skills/education_communication"
ssh $SERVER "mkdir -p $REMOTE_DIR/skills/brainstorm"

scp skills/workplace_jungle/SKILL.md $SERVER:$REMOTE_DIR/skills/workplace_jungle/
scp skills/family_relationship/SKILL.md $SERVER:$REMOTE_DIR/skills/family_relationship/
scp skills/education_communication/SKILL.md $SERVER:$REMOTE_DIR/skills/education_communication/
scp skills/brainstorm/SKILL.md $SERVER:$REMOTE_DIR/skills/brainstorm/

# 5. 重启服务
echo ""
echo "5. 重启服务..."
ssh $SERVER << 'EOF'
cd ~/gemini-audio-service
source venv/bin/activate

# 停止旧服务
pkill -f "python.*main.py" || echo "没有运行中的服务"

# 等待进程完全停止
sleep 2

# 启动新服务
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &

# 等待服务启动
sleep 5

# 检查服务是否运行
if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    echo ""
    echo "查看最新日志:"
    tail -30 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|技能|skill|ERROR"
else
    echo "❌ 服务启动失败"
    echo "查看错误日志:"
    tail -50 ~/gemini-audio-service.log
fi
EOF

echo ""
echo "========== 更新完成 =========="
