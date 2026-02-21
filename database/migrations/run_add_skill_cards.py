#!/usr/bin/env python3
"""执行 add_skill_cards 迁移：为 strategy_analysis 表添加 skill_cards 列"""
import asyncio
import os
import sys
from pathlib import Path

# 确保能加载项目模块
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

async def main():
    from dotenv import load_dotenv
    load_dotenv()
    
    from database.connection import engine
    from sqlalchemy import text
    
    sql_path = Path(__file__).parent / "add_skill_cards.sql"
    sql = sql_path.read_text(encoding="utf-8")
    
    async with engine.connect() as conn:
        await conn.execute(text(sql))
        await conn.commit()
    print("✅ add_skill_cards 迁移执行成功")

if __name__ == "__main__":
    asyncio.run(main())
