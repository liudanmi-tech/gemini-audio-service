#!/bin/bash

# 完整诊断脚本
SESSION_ID="d12f253d-608e-442d-833b-92e874f1efc5"

echo "========== 完整诊断 =========="
echo ""

cd ~/gemini-audio-service
source venv/bin/activate

echo "=== 1. 检查任务创建时间 ==="
python3 -c "
import sys
sys.path.insert(0, '.')
import asyncio
from database.connection import AsyncSessionLocal
from database.models import Session
from sqlalchemy import select
import uuid
from datetime import datetime, timezone

async def check():
    async with AsyncSessionLocal() as s:
        r = await s.execute(select(Session).where(Session.id == uuid.UUID('$SESSION_ID')))
        d = r.scalar_one_or_none()
        if d:
            now = datetime.now(timezone.utc)
            created = d.created_at
            if created.tzinfo is None:
                created = created.replace(tzinfo=timezone.utc)
            age = (now - created).total_seconds()
            print(f'创建时间: {created}')
            print(f'当前时间: {now}')
            print(f'任务年龄: {int(age)} 秒 ({int(age/60)} 分钟)')
            print(f'状态: {d.status}')

asyncio.run(check())
"

echo ""
echo "=== 2. 查看服务启动时间 ==="
ps -p $(pgrep -f 'python.*main.py') -o lstart,etime,cmd 2>/dev/null || echo "服务未运行"

echo ""
echo "=== 3. 查看日志文件信息 ==="
ls -lh ~/gemini-audio-service.log
echo "日志最后修改时间: $(stat -c %y ~/gemini-audio-service.log 2>/dev/null || stat -f %Sm ~/gemini-audio-service.log)"

echo ""
echo "=== 4. 查看最近的日志（所有任务）==="
tail -50 ~/gemini-audio-service.log | grep -E "上传|upload|创建异步|开始异步" | tail -10

echo ""
echo "=== 5. 检查代码中是否有文件大小检查 ==="
grep -A 5 "file_size < 1000" main.py | head -10

echo ""
echo "=== 6. 检查analyze_audio_async函数实现 ==="
grep -A 20 "async def analyze_audio_async" main.py | head -25
