"""
数据库初始化脚本
使用SQLAlchemy创建所有表
"""
import asyncio
import sys
from pathlib import Path

# 添加项目根目录到路径
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from database.connection import init_db, engine
from database.models import Base
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def main():
    """初始化数据库"""
    try:
        logger.info("开始初始化数据库...")
        await init_db()
        logger.info("数据库初始化完成！")
    except Exception as e:
        logger.error(f"数据库初始化失败: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        await engine.dispose()


if __name__ == "__main__":
    asyncio.run(main())
