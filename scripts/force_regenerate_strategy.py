#!/usr/bin/env python3
"""
删除指定 session 的策略分析记录，使下次 App 请求时重新生成（使用最新宫崎骏风格）。
用法: python3 scripts/force_regenerate_strategy.py <session_id>
"""
import os
import sys
import asyncio

# 添加项目根目录到 path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv()


async def main():
    session_id = sys.argv[1] if len(sys.argv) > 1 else None
    if not session_id:
        print("用法: python3 scripts/force_regenerate_strategy.py <session_id>")
        print("示例: python3 scripts/force_regenerate_strategy.py a85878d1-e792-42bc-a348-952754430ba7")
        sys.exit(1)

    from sqlalchemy import delete, select, text
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
    from sqlalchemy.orm import sessionmaker
    from database.connection import engine
    from database.models import StrategyAnalysis
    import uuid

    try:
        uid = uuid.UUID(session_id)
    except ValueError:
        print(f"❌ 无效的 session_id: {session_id}")
        sys.exit(1)

    async with engine.begin() as conn:
        r = await conn.execute(delete(StrategyAnalysis).where(StrategyAnalysis.session_id == uid))
        n = r.rowcount if hasattr(r, 'rowcount') else 0
        if n == 0:
            print(f"⚠️ session {session_id} 没有策略分析记录，无需删除")
        else:
            print(f"✅ 已删除 session {session_id} 的策略分析记录 (共 {n} 条)")
        print("请在 App 中打开该任务详情并刷新，将自动重新生成（宫崎骏风格）")

    await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
