#!/bin/bash
# 在远程服务器上执行数据库迁移

SERVER="admin@47.79.254.213"
REMOTE_DIR="~/gemini-audio-service"

echo "========== 准备在远程服务器执行数据库迁移 =========="
echo "服务器: $SERVER"
echo ""

# 1. 上传迁移文件到服务器
echo "1. 上传迁移文件..."
scp database/migrations/add_skills_tables.sql $SERVER:$REMOTE_DIR/database/migrations/
scp database/migrations/run_migration_v0.4.py $SERVER:$REMOTE_DIR/database/migrations/

# 2. 在服务器上执行迁移
echo ""
echo "2. 在服务器上执行迁移..."
ssh $SERVER << 'EOF'
cd ~/gemini-audio-service

# 激活虚拟环境并执行迁移
source venv/bin/activate 2>/dev/null || echo "虚拟环境未找到，使用系统 Python"

# 执行迁移
python3 database/migrations/run_migration_v0.4.py

# 检查迁移结果
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 迁移执行成功！"
    echo ""
    echo "验证迁移结果："
    python3 << 'PYEOF'
import asyncio
import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

async def verify():
    database_url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/gemini_audio_db")
    # 解析 URL
    if "postgresql+asyncpg://" in database_url:
        database_url = database_url.replace("postgresql+asyncpg://", "postgresql://")
    elif "postgresql://" not in database_url:
        database_url = "postgresql://" + database_url
    
    from urllib.parse import urlparse
    parsed = urlparse(database_url)
    
    try:
        conn = await asyncpg.connect(
            host=parsed.hostname or 'localhost',
            port=parsed.port or 5432,
            user=parsed.username or 'postgres',
            password=parsed.password or 'postgres',
            database=parsed.path.lstrip('/') or 'gemini_audio_db'
        )
        
        # 检查表是否存在
        skills_exists = await conn.fetchval("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'skills'
            )
        """)
        
        executions_exists = await conn.fetchval("""
            SELECT EXISTS (
                SELECT FROM information_schema.tables 
                WHERE table_name = 'skill_executions'
            )
        """)
        
        # 检查 strategy_analysis 表的新字段
        columns = await conn.fetch("""
            SELECT column_name 
            FROM information_schema.columns 
            WHERE table_name = 'strategy_analysis' 
            AND column_name IN ('applied_skills', 'scene_category', 'scene_confidence')
        """)
        
        print(f"  - skills 表: {'✅ 存在' if skills_exists else '❌ 不存在'}")
        print(f"  - skill_executions 表: {'✅ 存在' if executions_exists else '❌ 不存在'}")
        print(f"  - strategy_analysis 新字段: ✅ {len(columns)} 个字段已添加")
        
        await conn.close()
    except Exception as e:
        print(f"  ❌ 验证失败: {e}")

asyncio.run(verify())
PYEOF
else
    echo ""
    echo "❌ 迁移执行失败，请检查错误信息"
fi
EOF

echo ""
echo "========== 迁移完成 =========="
