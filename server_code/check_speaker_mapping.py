#!/usr/bin/env python3
"""
诊断某次任务的声纹匹配结果：查 DB 中该 session 的 audio_url/audio_path、speaker_mapping、conversation_summary。
在服务器上执行（需能连到同一数据库）：
  export DATABASE_URL="postgresql+asyncpg://..."
  python3 check_speaker_mapping.py 0e63e91d-56c3-4599-935c-d892dd89348f
或：
  SPEAKER_CHECK_SESSION_ID=0e63e91d-56c3-4599-935c-d892dd89348f python3 check_speaker_mapping.py
"""
import asyncio
import os
import sys
import uuid
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
        pass  # 无 dotenv 时依赖环境变量 DATABASE_URL

from sqlalchemy import select, text
from database.connection import AsyncSessionLocal
from database.models import Session, AnalysisResult, Profile


async def main():
    session_id = (sys.argv[1:] or [os.getenv("SPEAKER_CHECK_SESSION_ID")])[0]
    if not session_id:
        print("用法: python3 check_speaker_mapping.py <session_id>")
        print("  或: SPEAKER_CHECK_SESSION_ID=<session_id> python3 check_speaker_mapping.py")
        sys.exit(1)
    try:
        uuid.UUID(session_id)
    except ValueError:
        print(f"无效的 session_id: {session_id}")
        sys.exit(1)

    async with AsyncSessionLocal() as db:
        # Session: audio_url, audio_path
        r = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
        sess = r.scalar_one_or_none()
        if not sess:
            print(f"未找到 session: {session_id}")
            sys.exit(1)
        print("=== Session ===")
        print(f"  id: {sess.id}")
        print(f"  title: {sess.title}")
        print(f"  user_id: {sess.user_id}")
        print(f"  audio_url: {getattr(sess, 'audio_url', None)}")
        print(f"  audio_path: {getattr(sess, 'audio_path', None)}")

        # AnalysisResult: speaker_mapping, conversation_summary
        r2 = await db.execute(select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id)))
        ar = r2.scalar_one_or_none()
        if not ar:
            print("\n未找到 analysis_result（该任务可能尚未完成分析）")
            sys.exit(0)
        print("\n=== AnalysisResult ===")
        print(f"  speaker_mapping: {getattr(ar, 'speaker_mapping', None)}")
        print(f"  conversation_summary: {getattr(ar, 'conversation_summary', None) or '(空)'}")

        # 若有 speaker_mapping，解析档案名
        sm = getattr(ar, 'speaker_mapping', None)
        if isinstance(sm, dict) and sm and sess.user_id:
            profile_ids = list(sm.values())
            r3 = await db.execute(
                select(Profile.id, Profile.name).where(
                    Profile.user_id == sess.user_id,
                    Profile.id.in_([uuid.UUID(pid) for pid in profile_ids])
                )
            )
            id_to_name = {str(row.id): (row.name or "未知") for row in r3.all()}
            print("\n=== 说话人 -> 档案名 ===")
            for sp, pid in sm.items():
                print(f"  {sp} -> profile_id={pid} name={id_to_name.get(pid, '?')}")
        else:
            print("\n(无 speaker_mapping 或为空，界面会显示 Speaker_0/Speaker_1)")
            if not getattr(sess, 'audio_url', None) and not getattr(sess, 'audio_path', None):
                print("  可能原因: 该任务分析时未保存原音频（audio_url/audio_path 为空）")
            elif not sm:
                print("  可能原因: 分析后声纹流程未匹配到档案（用户无档案或匹配失败）")


if __name__ == "__main__":
    asyncio.run(main())
