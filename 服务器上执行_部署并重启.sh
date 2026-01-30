#!/bin/bash
# 在服务器上执行：进入项目目录、执行迁移（如有）、重启服务
# 用法：SSH 登录后执行：bash ~/gemini-audio-service/服务器上执行_部署并重启.sh
# 若服务器上是 git 仓库，可取消下面 git pull 的注释

set -e
cd ~/gemini-audio-service

# 若服务器通过 git 拉代码，取消下面两行注释并在本机先 push 到远程
# git fetch origin && git reset --hard origin/main

source venv/bin/activate 2>/dev/null || true

# 执行 sessions.error_message 迁移（若未执行过会添加列，已存在则跳过）
if [ -f database/migrations/run_add_sessions_error_message.py ]; then
    echo "执行数据库迁移（sessions.error_message）..."
    python3 database/migrations/run_add_sessions_error_message.py || true
fi
# 执行 session_audio 与 speaker_mapping 迁移（声纹方案）
if [ -f database/migrations/run_add_session_audio_and_speaker_mapping.py ]; then
    echo "执行数据库迁移（session_audio + speaker_mapping）..."
    python3 database/migrations/run_add_session_audio_and_speaker_mapping.py || true
fi

echo "停止旧服务..."
pkill -f "python.*main.py" 2>/dev/null || echo "没有运行中的服务"
sleep 2

echo "启动服务..."
nohup python3 main.py > ~/gemini-audio-service.log 2>&1 &
sleep 5

if ps aux | grep -q "[p]ython.*main.py"; then
    echo "✅ 服务已启动"
    tail -20 ~/gemini-audio-service.log | grep -E "启动|Uvicorn|Application startup|技能|ERROR|Request" || tail -15 ~/gemini-audio-service.log
else
    echo "❌ 启动失败，查看日志:"
    tail -40 ~/gemini-audio-service.log
fi
