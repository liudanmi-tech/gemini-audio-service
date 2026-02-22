#!/usr/bin/env python3
"""诊断指定 session 的策略分析和技能卡片状态"""
import asyncio
import json
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dotenv import load_dotenv
load_dotenv()

async def main():
    session_id = sys.argv[1] if len(sys.argv) > 1 else "98a05df6-8d63-40ac-8dbd-dfc657902819"
    sid = uuid.UUID(session_id)
    
    from database.connection import AsyncSessionLocal
    from database.models import StrategyAnalysis, AnalysisResult, Session
    from sqlalchemy import select
    
    async with AsyncSessionLocal() as db:
        # 1. 检查 strategy_analysis
        r = await db.execute(select(StrategyAnalysis).where(StrategyAnalysis.session_id == sid))
        sa = r.scalar_one_or_none()
        if not sa:
            print(f"❌ 未找到 strategy_analysis: {session_id}")
            print("   可能原因: 策略尚未生成，或生成失败。可尝试 force_regenerate=true 重新生成。")
            return
        
        print(f"=== strategy_analysis {session_id} ===")
        print(f"visual_data 数量: {len(sa.visual_data or [])}")
        print(f"strategies 数量: {len(sa.strategies or [])}")
        print(f"applied_skills: {sa.applied_skills}")
        print(f"scene_category: {sa.scene_category}")
        
        skill_cards = getattr(sa, "skill_cards", None) or []
        print(f"skill_cards 数量: {len(skill_cards)}")
        
        if skill_cards:
            for i, c in enumerate(skill_cards):
                ct = c.get("content_type", "?")
                skill_id = c.get("skill_id", "?")
                if ct == "emotion":
                    cnt = c.get("content", {})
                    print(f"  卡片{i+1}: {skill_id} [emotion] mood={cnt.get('mood_state')} sigh={cnt.get('sigh_count')} haha={cnt.get('haha_count')}")
                else:
                    cnt = c.get("content", {})
                    v = cnt.get("visual", [])
                    s = cnt.get("strategies", [])
                    img_ok = sum(1 for x in v if x.get("image_url") or x.get("image_base64")) if v else 0
                    print(f"  卡片{i+1}: {skill_id} [strategy] visual={len(v)} (含图{img_ok}) strategies={len(s)}")
        else:
            print("  (skill_cards 为空，可能为旧数据，API 会从 visual_data+strategies 构造兼容结构)")
        
        # visual 中图片情况
        for i, v in enumerate(sa.visual_data or []):
            vd = v if isinstance(v, dict) else (getattr(v, "__dict__", {}) or {})
            has_url = bool(vd.get("image_url"))
            has_b64 = bool(vd.get("image_base64"))
            print(f"  visual[{i}]: image_url={has_url} image_base64={has_b64}")
        
        # 2. 检查 analysis_result (transcript)
        ar_r = await db.execute(select(AnalysisResult).where(AnalysisResult.session_id == sid))
        ar = ar_r.scalar_one_or_none()
        if ar:
            tr = ar.transcript
            if isinstance(tr, str):
                try:
                    tr = json.loads(tr)
                except:
                    tr = []
            print(f"\n=== analysis_result ===")
            print(f"transcript 条数: {len(tr) if isinstance(tr, list) else 0}")
        else:
            print("\n❌ 未找到 analysis_result (无 transcript)")
        
        # 3. session 基本信息
        s_r = await db.execute(select(Session).where(Session.id == sid))
        s = s_r.scalar_one_or_none()
        if s:
            print(f"\n=== session ===")
            print(f"status: {s.status} user_id: {s.user_id}")

if __name__ == "__main__":
    asyncio.run(main())
