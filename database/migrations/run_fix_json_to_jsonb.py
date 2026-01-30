"""
在服务器上执行：将可能为 json (OID 114) 的列改为 jsonb，修复 asyncpg 报 Unknown PG numeric type: 114
使用前需在项目根目录或设置 .env 中的 DATABASE_URL。
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
        "database": parsed.path.lstrip("/") or "gemini_audio_db",
    }


# 逐条执行，某条失败不影响其余（如列不存在、已是 jsonb/double precision）
# 每项: (显示名, SQL, 目标类型说明)
STATEMENTS = [
    ("strategy_analysis.visual_data", "ALTER TABLE strategy_analysis ALTER COLUMN visual_data TYPE jsonb USING visual_data::jsonb", "jsonb"),
    ("strategy_analysis.strategies", "ALTER TABLE strategy_analysis ALTER COLUMN strategies TYPE jsonb USING strategies::jsonb", "jsonb"),
    ("strategy_analysis.applied_skills", "ALTER TABLE strategy_analysis ALTER COLUMN applied_skills TYPE jsonb USING COALESCE(applied_skills::jsonb, '[]'::jsonb)", "jsonb"),
    ("analysis_results.dialogues", "ALTER TABLE analysis_results ALTER COLUMN dialogues TYPE jsonb USING dialogues::jsonb", "jsonb"),
    ("analysis_results.stats", "ALTER TABLE analysis_results ALTER COLUMN stats TYPE jsonb USING stats::jsonb", "jsonb"),
    ("analysis_results.call1_result", "ALTER TABLE analysis_results ALTER COLUMN call1_result TYPE jsonb USING call1_result::jsonb", "jsonb"),
    ("analysis_results.speaker_mapping", "ALTER TABLE analysis_results ALTER COLUMN speaker_mapping TYPE jsonb USING speaker_mapping::jsonb", "jsonb"),
    ("skills.metadata", "ALTER TABLE skills ALTER COLUMN metadata TYPE jsonb USING COALESCE(metadata::jsonb, '{}'::jsonb)", "jsonb"),
    ("strategy_analysis.scene_confidence", "ALTER TABLE strategy_analysis ALTER COLUMN scene_confidence TYPE double precision USING (COALESCE((scene_confidence::text)::double precision, 0.5))", "double precision"),
    ("skill_executions.confidence_score", "ALTER TABLE skill_executions ALTER COLUMN confidence_score TYPE double precision USING (COALESCE((confidence_score::text)::double precision, 0.5))", "double precision"),
]


async def run():
    database_url = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/gemini_audio_db")
    db_config = parse_database_url(database_url)
    conn = await asyncpg.connect(
        host=db_config["host"],
        port=db_config["port"],
        user=db_config["user"],
        password=db_config["password"],
        database=db_config["database"],
    )
    try:
        for name, sql, target in STATEMENTS:
            try:
                await conn.execute(sql)
                print(f"✅ {name} -> {target}")
            except Exception as e:
                msg = str(e).lower()
                if "already" in msg or "duplicate" in msg or "does not exist" in msg:
                    print(f"⚠️ {name} 跳过: {e}")
                else:
                    print(f"❌ {name} 失败: {e}")
        print("✅ json -> jsonb 迁移完成")
        return True
    finally:
        await conn.close()


if __name__ == "__main__":
    ok = asyncio.run(run())
    sys.exit(0 if ok else 1)
