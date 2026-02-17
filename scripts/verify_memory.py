#!/usr/bin/env python3
"""
v0.6 记忆功能本地验证脚本

用法:
  1. 确保 .env 中已设置 GEMINI_API_KEY
  2. 安装依赖: pip install mem0ai chromadb (或 pip install mem0ai -i https://pypi.tuna.tsinghua.edu.cn/simple)
  3. 运行: python3 scripts/verify_memory.py
"""
import os
import sys
from pathlib import Path

# 加载项目根目录
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

def main():
    from dotenv import load_dotenv
    load_dotenv()
    key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not key or len(key) < 10:
        print("❌ 请在 .env 中设置 GEMINI_API_KEY")
        return 1

    print("=" * 50)
    print("v0.6 记忆功能验证")
    print("=" * 50)

    from services.memory_service import get_memory, add_memory, search_memory

    m = get_memory()
    if not m:
        print("❌ Mem0 初始化失败（请检查依赖与 API Key）")
        return 1
    print("✅ Mem0 初始化成功")

    # 测试写入
    ok = add_memory(
        "王总和李总讨论了A项目，李总汇报给王总，双方关系紧张。",
        "test-user",
        metadata={"session_id": "verify-session-1"},
    )
    if not ok:
        print("❌ add_memory 失败")
        return 1
    print("✅ add_memory 成功")

    # 测试检索
    results = search_memory("王总 李总 A项目", "test-user", limit=3)
    if not results:
        print("⚠️ search_memory 未返回结果（可能是首次写入尚未索引）")
    else:
        print(f"✅ search_memory 成功，返回 {len(results)} 条")
        for i, r in enumerate(results[:2]):
            print(f"   [{i}] {r[:80]}...")

    print("=" * 50)
    print("验证完成。可启动 main.py 进行完整流程测试。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
