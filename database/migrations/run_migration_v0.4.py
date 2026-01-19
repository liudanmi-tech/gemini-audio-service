"""
执行 v0.4 技能化架构数据库迁移
使用 asyncpg 直接执行 SQL
"""
import asyncio
import os
import sys
from pathlib import Path
import asyncpg
from urllib.parse import urlparse
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def parse_database_url(url: str) -> dict:
    """解析数据库 URL"""
    # 支持 postgresql+asyncpg:// 和 postgresql:// 格式
    url = url.replace('postgresql+asyncpg://', 'postgresql://')
    parsed = urlparse(url)
    
    return {
        'host': parsed.hostname or 'localhost',
        'port': parsed.port or 5432,
        'user': parsed.username or 'postgres',
        'password': parsed.password or 'postgres',
        'database': parsed.path.lstrip('/') or 'gemini_audio_db'
    }


async def run_migration():
    """执行数据库迁移"""
    try:
        # 从环境变量获取数据库 URL
        from dotenv import load_dotenv
        load_dotenv()
        
        database_url = os.getenv(
            "DATABASE_URL",
            "postgresql://postgres:postgres@localhost:5432/gemini_audio_db"
        )
        
        # 解析数据库连接信息
        db_config = parse_database_url(database_url)
        
        logger.info(f"连接数据库: {db_config['user']}@{db_config['host']}:{db_config['port']}/{db_config['database']}")
        
        # 读取 SQL 文件
        migration_file = Path(__file__).parent / "add_skills_tables.sql"
        
        if not migration_file.exists():
            logger.error(f"迁移文件不存在: {migration_file}")
            return False
        
        logger.info(f"读取迁移文件: {migration_file}")
        with open(migration_file, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # 连接数据库
        conn = await asyncpg.connect(
            host=db_config['host'],
            port=db_config['port'],
            user=db_config['user'],
            password=db_config['password'],
            database=db_config['database']
        )
        
        try:
            # 执行 SQL（整个文件作为一个事务）
            logger.info("开始执行数据库迁移...")
            await conn.execute(sql_content)
            logger.info("✅ 数据库迁移完成！")
            return True
        except Exception as e:
            # 如果是 "already exists" 错误，可以忽略
            error_msg = str(e).lower()
            if 'already exists' in error_msg or 'duplicate' in error_msg:
                logger.warning(f"⚠️ 某些对象已存在，但迁移继续: {e}")
                return True
            else:
                logger.error(f"❌ 数据库迁移失败: {e}")
                raise
        finally:
            await conn.close()
        
    except asyncpg.exceptions.InvalidPasswordError:
        logger.error("❌ 数据库密码错误")
        return False
    except asyncpg.exceptions.InvalidCatalogNameError:
        logger.error(f"❌ 数据库不存在: {db_config['database']}")
        logger.info("请先创建数据库或检查 DATABASE_URL 配置")
        return False
    except asyncpg.exceptions.ConnectionDoesNotExistError:
        logger.error("❌ 无法连接到数据库")
        logger.info("请检查数据库服务是否运行，以及 DATABASE_URL 配置是否正确")
        return False
    except Exception as e:
        logger.error(f"❌ 数据库迁移失败: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return False


if __name__ == "__main__":
    success = asyncio.run(run_migration())
    sys.exit(0 if success else 1)
