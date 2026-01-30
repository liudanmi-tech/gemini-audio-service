"""
在服务器上执行：检查哪些列仍是 json (会触发 PG type 114)，需改为 jsonb。
用法：在项目根目录执行 python3 database/migrations/check_json_columns.py
需要 .env 中 DATABASE_URL 或默认 postgresql://...
"""
import asyncio
import os
import sys
from pathlib import Path
from urllib.parse import urlparse

_root = Path(__file__).resolve().parents[2]
_env = _root / ".env"
if _env.exists():
    try:
        from dotenv import load_dotenv
        load_dotenv(_env)
    except ImportError:
        pass

try:
    import asyncpg
except ImportError:
    print("请先安装 asyncpg: pip install asyncpg")
    sys.exit(1)


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
    print(f"连接数据库: {db_config['host']}:{db_config['port']}/{db_config['database']}")
    conn = await asyncpg.connect(
        host=db_config["host"],
        port=db_config["port"],
        user=db_config["user"],
        password=db_config["password"],
        database=db_config["database"],
    )
    try:
        # 1. 查 json/jsonb 列（json 会导致 OID 114）
        rows = await conn.fetch("""
            SELECT table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name IN ('strategy_analysis', 'analysis_results', 'skills', 'skill_executions')
              AND data_type IN ('json', 'jsonb')
            ORDER BY table_name, column_name
        """)
        print("\n当前 json/jsonb 列：")
        print("-" * 60)
        has_json = False
        for r in rows:
            table_name, column_name, data_type = r["table_name"], r["column_name"], r["data_type"]
            mark = "  <-- 需执行迁移" if data_type == "json" else ""
            if data_type == "json":
                has_json = True
            print(f"  {table_name}.{column_name}  =>  {data_type}{mark}")
        # 2. 关键列：应为 double precision，若为 json 会报 DatatypeMismatchError
        float_cols = await conn.fetch("""
            SELECT table_name, column_name, data_type
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND ((table_name = 'strategy_analysis' AND column_name = 'scene_confidence')
                   OR (table_name = 'skill_executions' AND column_name = 'confidence_score'))
            ORDER BY table_name, column_name
        """)
        print("\n关键列（应为 double precision，若为 json 会报错）：")
        print("-" * 60)
        need_float_migration = False
        for r in float_cols:
            table_name, column_name, data_type = r["table_name"], r["column_name"], r["data_type"]
            ok = data_type in ("double precision", "real")
            mark = "" if ok else "  <-- 需改为 double precision"
            if not ok:
                need_float_migration = True
            print(f"  {table_name}.{column_name}  =>  {data_type}{mark}")
        print("-" * 60)
        if has_json:
            print("\n请执行: python3 database/migrations/run_fix_json_to_jsonb.py")
        if need_float_migration:
            print("\n请执行: python3 database/migrations/run_fix_json_to_jsonb.py （含 scene_confidence/confidence_score -> double precision）")
            print("若仍失败，可在 psql 中手动执行：")
            print("  ALTER TABLE strategy_analysis ALTER COLUMN scene_confidence TYPE double precision USING (COALESCE((scene_confidence::text)::double precision, 0.5));")
            print("  ALTER TABLE skill_executions ALTER COLUMN confidence_score TYPE double precision USING (COALESCE((confidence_score::text)::double precision, 0.5));")
        if not has_json and not need_float_migration:
            print("\n所有相关列类型正确。若仍报错请检查是否连错库或未重启应用。")
    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(run())
