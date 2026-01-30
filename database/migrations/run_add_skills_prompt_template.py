"""
在服务器上执行：为 skills 表添加 prompt_template 列
技能模板落表后，查表即可用，不依赖 SKILL.md 解析。使用前需在项目根目录或设置 .env 中的 DATABASE_URL。
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
    sql_file = Path(__file__).parent / "add_skills_prompt_template.sql"
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
        print("❌ 无法连接数据库:", e)
        return False
    try:
        for stmt in sql_content.split(";"):
            stmt = stmt.strip()
            if not stmt:
                continue
            # 若整段只是注释（不含 ALTER）则跳过，否则执行（首段可能是 "-- 注释\nALTER ..."）
            if stmt.startswith("--") and "ALTER" not in stmt.upper():
                continue
            try:
                await conn.execute(stmt)
                print("✅ 已执行:", stmt[:60] + "..." if len(stmt) > 60 else stmt)
            except Exception as e:
                if "already exists" in str(e).lower() or "duplicate" in str(e).lower():
                    print("⚠️ 列已存在，跳过")
                else:
                    raise
        print("✅ skills.prompt_template 迁移已完成")
    finally:
        await conn.close()
    return True


if __name__ == "__main__":
    asyncio.run(run())
