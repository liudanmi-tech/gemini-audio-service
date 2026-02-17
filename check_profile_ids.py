#!/usr/bin/env python3
"""查询指定 profile_id 的 name、relationship_type，用于判定声纹映射是否反了。"""
import asyncio
import sys
from pathlib import Path

_root = Path(__file__).resolve().parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))
_env = _root / ".env"
if _env.exists():
    try:
        from dotenv import load_dotenv
        load_dotenv(_env)
    except ImportError:
        pass

from sqlalchemy import select
from database.connection import AsyncSessionLocal
from database.models import Profile
import uuid

IDS = [
    "1ddd678c-fd33-4c0c-9e7f-7772ce997a97",
    "7634ace0-c21e-4974-9587-002e20403280",
]

async def main():
    async with AsyncSessionLocal() as db:
        r = await db.execute(
            select(Profile.id, Profile.name, Profile.relationship_type).where(
                Profile.id.in_([uuid.UUID(i) for i in IDS])
            )
        )
        rows = r.all()
        print("=== Profile 详情 ===")
        for row in rows:
            pid, name, rel = str(row[0]), row[1] or "未知", (row[2] or "未知")
            print(f"  profile_id: {pid}")
            print(f"  name:       {name}")
            print(f"  relationship_type: {rel}")
            print()
        if not rows:
            print("  未查到这两个 profile_id（请确认 DATABASE_URL 与库内数据）")

if __name__ == "__main__":
    asyncio.run(main())
