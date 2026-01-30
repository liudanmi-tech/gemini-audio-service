"""
在服务器上执行：为 sessions 表添加 error_message 列
用于录音分析失败原因可见性。使用前需在项目根目录或设置 .env 中的 DATABASE_URL。
"""
import asyncio
import os
import sys
from pathlib import Path
import asyncpg
from urllib.parse import urlparse

# 从项目根目录加载 .env
_root = Path(__file__).resolve().parents[2]
_env = _root / ".env"
if _env.exists():
    from dotenv import load_dotenv
    load_dotenv(_env)


def parse_database_url(url: str) -> dict:
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    parsed = urlparse(url)
    return {
        "host": parsed.hostname or "localhost",
        "port": parsed.port or 5432,
        "user": parsed.username or "postgres",
        "password": parsed.password or "postgres",
        "database": parsed.path.lstrip("/") or "gemini_audio_db",
    }


async def run():
    database_url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/gemini_audio_db")
    db_config = parse_database_url(database_url)
    sql_file = Path(__file__).parent / "add_sessions_error_message.sql"
    if not sql_file.exists():
        print(f"迁移文件不存在: {sql_file}")
        return False
    sql_content = sql_file.read_text(encoding="utf-8")
    conn = await asyncpg.connect(
        host=db_config["host"],
        port=db_config["port"],
        user=db_config["user"],
        password=db_config["password"],
        database=db_config["database"],
    )
    try:
        await conn.execute(sql_content)
        print("✅ sessions.error_message 迁移已执行")
        return True
    except Exception as e:
        if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
            print("⚠️ 列已存在，跳过")
            return True
        print(f"❌ 迁移失败: {e}")
        return False
    finally:
        await conn.close()


if __name__ == "__main__":
    ok = asyncio.run(run())
    sys.exit(0 if ok else 1)
