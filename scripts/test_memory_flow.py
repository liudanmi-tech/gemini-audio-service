#!/usr/bin/env python3
"""
v0.6 记忆流程模拟：仅验证代码路径与日志，不依赖真实 API
用于快速验证 [记忆] 日志是否会输出
"""
import os
import sys
import logging
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# 确保 INFO 级别日志输出
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger(__name__)


def test_build_payload():
    """测试 build_memory_payload 逻辑"""
    from services.memory_service import build_memory_payload

    transcript = [
        {"speaker": "Speaker_0", "text": "这个项目你来负责"},
        {"speaker": "Speaker_1", "text": "好的王总"},
    ]
    conversation_summary = "王总（领导）和李总（下属）讨论项目分工。"
    speaker_mapping = {"Speaker_0": "prof-1", "Speaker_1": "prof-2"}
    profile_names = {"prof-1": "王总（领导）", "prof-2": "李总（下属）"}

    payload = build_memory_payload(
        transcript, conversation_summary, speaker_mapping, profile_names
    )
    print("\n=== build_memory_payload 输出 ===")
    print(payload[:300] + "..." if len(payload) > 300 else payload)
    return payload


def test_add_and_search():
    """测试 add_memory 与 search_memory（需 Mem0 + Gemini）"""
    from dotenv import load_dotenv

    load_dotenv()
    key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not key or len(key) < 10:
        print("\n⚠️ 跳过 add/search：无 GEMINI_API_KEY")
        return

    from services.memory_service import get_memory, add_memory, search_memory

    m = get_memory()
    if not m:
        print("\n⚠️ 跳过 add/search：Mem0 未初始化")
        return

    test_user = "test-flow-user"
    test_meta = {"session_id": "test-flow-session"}

    print("\n=== 调用 add_memory ===")
    ok = add_memory(
        "王总和李总讨论了A项目，李总汇报给王总。",
        test_user,
        metadata=test_meta,
    )
    print(f"add_memory 结果: success={ok}")

    if ok:
        print("\n=== 调用 search_memory ===")
        results = search_memory("王总 李总", test_user, limit=3)
        print(f"search_memory 结果: 命中 {len(results)} 条")
        for i, r in enumerate(results[:2]):
            print(f"  [{i}] {r[:80]}...")


def main():
    print("=" * 50)
    print("v0.6 记忆流程实验")
    print("=" * 50)

    print("\n[1] 测试 build_memory_payload")
    test_build_payload()

    print("\n[2] 测试 add_memory / search_memory")
    test_add_and_search()

    print("\n" + "=" * 50)
    print("完成。若上面出现 [记忆] 日志，说明 memory_service 日志正常。")
    print("=" * 50)


if __name__ == "__main__":
    main()
