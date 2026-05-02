#!/usr/bin/env python3
"""
检查某 session 是否匹配/写入了记忆。

在服务器上执行（需能连到同一数据库，且 Mem0 已配置）：
  cd ~/gemini-audio-service && source venv/bin/activate
  python3 check_session_memory.py 2eb2ad57-e4a7-4fed-b3dd-2876ff24af2b

或本地执行（需 DATABASE_URL 能连到 RDS）：
  export DATABASE_URL="postgresql+asyncpg://..."
  python3 check_session_memory.py 2eb2ad57-e4a7-4fed-b3dd-2876ff24af2b
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
        pass

from sqlalchemy import select
from database.connection import AsyncSessionLocal
from database.models import Session, AnalysisResult, StrategyAnalysis


async def main():
    session_id = (sys.argv[1:] or [os.getenv("SESSION_ID")])[0]
    if not session_id:
        print("用法: python3 check_session_memory.py <session_id>")
        print("  或: SESSION_ID=<session_id> python3 check_session_memory.py")
        sys.exit(1)
    try:
        uuid.UUID(session_id)
    except ValueError:
        print(f"无效的 session_id: {session_id}")
        sys.exit(1)

    async with AsyncSessionLocal() as db:
        r = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
        sess = r.scalar_one_or_none()
        if not sess:
            print(f"未找到 session: {session_id}")
            sys.exit(1)
        user_id = str(sess.user_id)

        r2 = await db.execute(select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id)))
        ar = r2.scalar_one_or_none()
        if not ar:
            print("\n未找到 AnalysisResult（该任务可能尚未完成音频分析）")
            print("记忆检索在策略分析阶段进行，需先完成音频分析。")
            sys.exit(0)

        r3 = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        sa = r3.scalar_one_or_none()

        print("=== 记忆检查 ===")
        print(f"session_id: {session_id}")
        print(f"user_id: {user_id}")
        print(f"有 AnalysisResult: ✓")
        print(f"有 StrategyAnalysis: {'✓' if sa else '✗（未生成策略或生成中）'}")

        # B 钩子条件：有 conversation_summary + speaker_mapping + profile_names
        conv_sum = getattr(ar, "conversation_summary", None) or ""
        sm = getattr(ar, "speaker_mapping", None) or {}
        has_b_hook_data = bool(conv_sum and sm)
        print(f"\n[记忆写入 B 钩子] 条件满足: {'✓' if has_b_hook_data else '✗'} "
              f"(conversation_summary={bool(conv_sum)} speaker_mapping={bool(sm)})")

        # C 钩子：策略生成完成后写入策略文本
        print(f"[记忆写入 C 钩子] 策略已生成: {'✓（会写入）' if sa else '✗（未生成策略）'}")

        # 模拟策略阶段的记忆检索
        search_query = conv_sum or (ar.summary or "")
        if not search_query and ar.transcript:
            transcript = ar.transcript if isinstance(ar.transcript, list) else []
            search_query = " ".join((t.get("text", "") or "")[:100] for t in transcript[:5])

        print(f"\n[记忆检索] 策略阶段会用 conversation_summary/summary 检索:")
        print(f"  search_query 长度: {len(search_query)}")
        if not search_query:
            print("  → 检索会跳过（query 为空）")
            sys.exit(0)

        # 实际调用 Mem0 检索
        try:
            from services.memory_service import search_memory
            mem_results = await asyncio.to_thread(
                search_memory, search_query, user_id, limit=5
            )
            if mem_results:
                print(f"  → 命中 {len(mem_results)} 条记忆，已注入技能 context")
                for i, m in enumerate(mem_results[:3], 1):
                    preview = (m[:80] + "…") if len(m) > 80 else m
                    print(f"    {i}. {preview}")
            else:
                print("  → 无命中（Mem0 中暂无与该对话相关的记忆）")
        except Exception as e:
            print(f"  → 检索失败或 Mem0 未配置: {e}")


if __name__ == "__main__":
    asyncio.run(main())
