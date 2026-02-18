#!/usr/bin/env python3
"""
诊断 session 的 strategy_analysis visual_data 中的图片字段
用法: python3 scripts/check_visual_data.py <session_id>
"""
import asyncio
import sys
import uuid


async def main():
    session_id = sys.argv[1] if len(sys.argv) > 1 else "ff15831b-523a-428a-8aeb-009ba63a9e9a"
    
    from dotenv import load_dotenv
    load_dotenv()
    from sqlalchemy import select
    from database.connection import AsyncSessionLocal
    from database.models import StrategyAnalysis, Session
    
    async with AsyncSessionLocal() as db:
        # 查 session 是否存在
        r = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
        s = r.scalar_one_or_none()
        if not s:
            print(f"❌ 未找到 session {session_id}")
            return
        print(f"✅ session 存在，user_id={s.user_id}")
        
        r = await db.execute(select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id)))
        sa = r.scalar_one_or_none()
        if not sa:
            print("❌ 未找到 strategy_analysis 记录")
            return
        print("✅ 找到 strategy_analysis")
        print(f"  visual_data 数量: {len(sa.visual_data) if sa.visual_data else 0}")
        if sa.visual_data:
            for i, v in enumerate(sa.visual_data):
                vd = v if isinstance(v, dict) else getattr(v, "__dict__", {})
                has_url = bool(vd.get("image_url"))
                has_b64 = bool(vd.get("image_base64"))
                b64_len = len(vd.get("image_base64") or "")
                url_val = (vd.get("image_url") or "")[:100]
                print(f"  visual[{i}]: image_url={has_url} image_base64={has_b64} b64_len={b64_len}")
                if url_val:
                    print(f"    image_url 前100字符: {url_val}...")
        else:
            print("  visual_data 为空")


if __name__ == "__main__":
    asyncio.run(main())
