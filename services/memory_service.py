"""
v0.6 记忆服务：基于 Mem0 + Qdrant（向量）+ Kuzu（图，可选）
Mac 本地部署：Qdrant 用 path 本地存储，Kuzu 需 cmake 编译
"""
import os
import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# 加载 .env 中的 GEMINI_API_KEY
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass
# Mem0 期望 GOOGLE_API_KEY，项目使用 GEMINI_API_KEY，自动兼容
if not os.environ.get("GOOGLE_API_KEY") and os.environ.get("GEMINI_API_KEY"):
    os.environ.setdefault("GOOGLE_API_KEY", os.environ["GEMINI_API_KEY"])

_MEMORY_INSTANCE = None


def build_memory_payload(
    transcript: list,
    conversation_summary: str,
    speaker_mapping: dict,
    profile_names: dict,
) -> str:
    """
    将 transcript 转为带档案名的对话文本，供 Mem0 抽取实体与关系。
    profile_names: profile_id -> "王总（领导）"
    """
    lines = []
    for t in transcript:
        sp = t.get("speaker", "未知")
        name = profile_names.get(speaker_mapping.get(sp, ""), sp)
        lines.append(f"{name}: {(t.get('text') or '').strip()}")
    dialogue_text = "\n".join(lines)
    return f"""对话内容：
{dialogue_text}

总结：{conversation_summary}"""


def get_memory_config():
    """获取 Mem0 配置（Mac 本地：Qdrant 向量库，path 本地存储；Kuzu 图库可选，需 cmake 编译）"""
    base_dir = Path(__file__).resolve().parent.parent
    data_dir = base_dir / "data"
    data_dir.mkdir(exist_ok=True)
    qdrant_path = str(data_dir / "mem0_qdrant")

    emb_dim = int(os.getenv("GEMINI_EMBEDDING_DIM", "1536"))
    config = {
        "vector_store": {
            "provider": "qdrant",
            "config": {
                "collection_name": "gemini_audio_memories",
                "path": qdrant_path,
                "on_disk": True,
                "embedding_model_dims": emb_dim,
            },
        },
        "llm": {
            "provider": "gemini",
            "config": {
                "model": os.getenv("GEMINI_FLASH_MODEL", "gemini-2.0-flash-001"),
                "temperature": 0.2,
                "max_tokens": 2000,
                "api_key": os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY"),
            },
        },
        "embedder": {
            "provider": "gemini",
            "config": {
                "model": os.getenv("GEMINI_EMBEDDING_MODEL", "models/gemini-embedding-001"),
                "api_key": os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY"),
                # 必须与 vector_store.embedding_model_dims 及 Qdrant meta.json size 一致
                "embedding_dims": emb_dim,
            },
        },
    }
    # Kuzu 图库需 cmake 编译，若未安装则仅用向量检索
    try:
        import kuzu
        kuzu_path = str(data_dir / "mem0_graph.kuzu")
        graph_custom_prompt = """仅抽取人物与人物、人物与项目之间的明确关系。
允许的关系类型：讨厌、不喜欢、负责、属于、汇报给、合作、冲突、提及。
人物名必须使用对话中出现的档案名（如王总、李总），禁止使用 Speaker_0、Speaker_1 等标签。
项目、事件等实体名保持对话中的原文。"""
        config["graph_store"] = {
            "provider": "kuzu",
            "config": {
                "db": kuzu_path,
                "custom_prompt": graph_custom_prompt,
                "threshold": 0.7,
            },
        }
    except ImportError:
        pass  # 无 Kuzu，enable_graph=False 时仅向量检索
    return config


def _has_graph_store():
    """是否配置了图存储（Kuzu 等）"""
    config = get_memory_config()
    return "graph_store" in config


def get_memory():
    """获取 Mem0 记忆实例（惰性初始化）"""
    global _MEMORY_INSTANCE
    if _MEMORY_INSTANCE is not None:
        return _MEMORY_INSTANCE
    try:
        from mem0 import Memory
        config = get_memory_config()
        emb = config.get("embedder", {}).get("config", {}).get("embedding_dims")
        vs_dims = config.get("vector_store", {}).get("config", {}).get("embedding_model_dims")
        logger.info(f"Mem0 配置: embedder.embedding_dims={emb} vector_store.embedding_model_dims={vs_dims}")
        _MEMORY_INSTANCE = Memory.from_config(config)
        mode = "Kuzu + Qdrant" if _has_graph_store() else "Qdrant（纯向量）"
        logger.info(f"Mem0 记忆服务初始化成功 ({mode}) embedding_dims={emb}")
        return _MEMORY_INSTANCE
    except ImportError as e:
        logger.warning(f"Mem0 未安装，记忆功能已禁用。请执行: pip install 'mem0ai[graph]' chromadb。错误: {e}")
        return None
    except Exception as e:
        logger.warning(f"Mem0 初始化失败，记忆功能已禁用: {e}")
        return None


def add_memory(
    messages_or_text,
    user_id: str,
    metadata: Optional[dict] = None,
    enable_graph: bool = True,
) -> bool:
    """
    同步写入记忆。若在 async 上下文中调用，应使用 asyncio.to_thread 或 run_in_executor 避免阻塞。
    无 graph_store 时自动使用 enable_graph=False。
    """
    memory = get_memory()
    if memory is None:
        logger.debug(f"[记忆] add_memory 跳过: Mem0 未初始化 user_id={user_id}")
        return False
    add_kwargs = {"user_id": user_id, "metadata": metadata or {}}
    # mem0ai 基础版（无 [graph]）不支持 enable_graph，不传以避免报错
    if enable_graph and _has_graph_store():
        add_kwargs["enable_graph"] = True
    try:
        payload_preview = str(messages_or_text)[:200] + "..." if len(str(messages_or_text)) > 200 else str(messages_or_text)
        logger.info(f"[记忆] add_memory 调用: user_id={user_id} metadata={metadata} payload_len={len(str(messages_or_text))} preview={payload_preview}")
        memory.add(messages_or_text, **add_kwargs)
        logger.info(f"[记忆] add_memory 成功: user_id={user_id} metadata={metadata}")
        return True
    except Exception as e:
        logger.warning(f"[记忆] add_memory 失败: user_id={user_id} error={e}", exc_info=True)
        return False


def search_memory(
    query: str,
    user_id: str,
    limit: int = 5,
    metadata_filter: Optional[dict] = None,
) -> list:
    """
    同步检索记忆，返回 memory 字符串列表。
    Mem0 search 返回格式: {"results": [{"memory": "...", "metadata": {...}, ...]}
    """
    memory = get_memory()
    if memory is None:
        logger.debug(f"[记忆] search_memory 跳过: Mem0 未初始化 user_id={user_id}")
        return []
    try:
        kwargs = {"query": query, "user_id": user_id, "limit": limit, "rerank": False}
        if metadata_filter:
            kwargs["metadata_filter"] = metadata_filter
        logger.info(f"[记忆] search_memory 调用: user_id={user_id} query_preview={query[:100]}... limit={limit}")
        result = memory.search(**kwargs)
        results = result.get("results", [])
        memories = [r.get("memory", "") for r in results if r.get("memory")]
        logger.info(f"[记忆] search_memory 返回: user_id={user_id} 命中={len(memories)} 条")
        return memories
    except Exception as e:
        logger.warning(f"[记忆] search_memory 失败: user_id={user_id} error={e}", exc_info=True)
        return []
