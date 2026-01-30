"""
仅将 scene_confidence / confidence_score 改为 double precision（若被误迁成 jsonb 时在服务器执行）。
在项目根目录：python3 database/migrations/fix_confidence_to_double_precision.py
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
    try:
        from dotenv import load_dotenv
        load_dotenv(_env)
    except ImportError:
        pass

def parse_database_url(url: str) -> dict:
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    parsed = urlparse(url)
    return {
        "host": parsed.hostname or "localhost",
        "port": parsed.port or 5432,
        "user": parsed.username or "postgres",
        "password": parsed.password or "postgres",
        "database": (parsed.path or "").lstrip("/") or "gemini_audio_db",
    }

STATEMENTS = [
    ("strategy_analysis.scene_confidence", "ALTER TABLE strategy_analysis ALTER COLUMN scene_confidence TYPE double precision USING (COALESCE((scene_confidence::text)::double precision, 0.5))"),
    ("skill_executions.confidence_score", "ALTER TABLE skill_executions ALTER COLUMN confidence_score TYPE double precision USING (COALESCE((confidence_score::text)::double precision, 0.5))"),
]

async def main():
    url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/gemini_audio_db")
    cfg = parse_database_url(url)
    conn = await asyncpg.connect(**cfg)
    try:
        for name, sql in STATEMENTS:
            try:
                await conn.execute(sql)
                print(f"✅ {name} -> double precision")
            except Exception as e:
                print(f"❌ {name} 失败: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
    sys.exit(0)
