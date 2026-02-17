#!/usr/bin/env python3
"""
在服务器上执行：为 sessions 表添加列表查询复合索引
用于 task list: WHERE user_id=? ORDER BY created_at DESC LIMIT n
可显著加速分页查询，缓解超时
"""
import asyncio
import os
import sys
from pathlib import Path

root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(root))
_env = root / ".env"
if _env.exists():
    from dotenv import load_dotenv
    load_dotenv(_env)

async def main():
    from sqlalchemy import text
    from database.connection import engine

    sql_file = Path(__file__).parent / "add_sessions_list_index.sql"
    sql = sql_file.read_text(encoding="utf-8").strip()
    try:
        async with engine.begin() as conn:
            await conn.execute(text(sql))
        print("✅ sessions 列表索引已创建: idx_sessions_user_created")
    except Exception as e:
        if "already exists" in str(e).lower():
            print("⚠️ 索引已存在，跳过")
        else:
            print(f"❌ 创建索引失败: {e}")
            raise

if __name__ == "__main__":
    asyncio.run(main())
