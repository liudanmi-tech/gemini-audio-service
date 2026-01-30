"""
在服务器上执行：为 sessions / analysis_results 添加原音频与说话人映射列
用于声纹方案：sessions.audio_url/audio_path，analysis_results.speaker_mapping/conversation_summary
"""
import asyncio
import os
import sys
from pathlib import Path
import asyncpg
from urllib.parse import urlparse

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
    sql_file = Path(__file__).parent / "add_session_audio_and_speaker_mapping.sql"
    if not sql_file.exists():
        print(f"迁移文件不存在: {sql_file}")
        return False
    sql_content = sql_file.read_text(encoding="utf-8")
    try:
        conn = await asyncpg.connect(
            host=db_config["host"],
            port=db_config["port"],
            user=db_config["user"],
            password=db_config["password"],
            database=db_config["database"],
        )
    except (OSError, ConnectionRefusedError) as e:
        print("❌ 无法连接数据库（Connection refused）。")
        print("  - 若在本地执行：请先启动 PostgreSQL，或")
        print("  - 在 .env 中设置 DATABASE_URL 为远程数据库地址（如阿里云 RDS），或")
        print("  - 在服务器上执行此迁移：ssh 登录后运行 python3 database/migrations/run_add_session_audio_and_speaker_mapping.py")
        print(f"  当前连接: {db_config['host']}:{db_config['port']}")
        return False
    except Exception as e:
        print(f"❌ 连接数据库失败: {e}")
        print("  请检查 .env 中的 DATABASE_URL 或到服务器上执行此迁移。")
        return False
    try:
        for stmt in sql_content.split(";"):
            stmt = stmt.strip()
            # 跳过空段；若整段只是注释（不含 ALTER）则跳过，否则执行（首段可能是 "-- 注释\nALTER ..."）
            if not stmt:
                continue
            if stmt.startswith("--") and "ALTER" not in stmt.upper():
                continue
            try:
                await conn.execute(stmt)
                print(f"✅ 已执行: {stmt[:60]}...")
            except Exception as e:
                if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
                    print("⚠️ 列已存在，跳过")
                else:
                    print(f"❌ 执行失败: {e}")
                    return False
        print("✅ session_audio 与 speaker_mapping 迁移已完成")
        return True
    finally:
        await conn.close()


if __name__ == "__main__":
    ok = asyncio.run(run())
    sys.exit(0 if ok else 1)
