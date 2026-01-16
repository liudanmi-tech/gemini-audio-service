"""
数据库连接配置
使用SQLAlchemy异步引擎连接PostgreSQL
"""
import os
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from dotenv import load_dotenv
import logging

logger = logging.getLogger(__name__)

# 加载环境变量
load_dotenv()

# 数据库URL
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/gemini_audio_db"
)

# 创建异步引擎
engine = create_async_engine(
    DATABASE_URL,
    echo=False,  # 设置为True可以看到SQL日志
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,  # 连接前检查连接是否有效
)

# 创建异步会话工厂
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

# 声明基类
Base = declarative_base()


async def get_db() -> AsyncSession:
    """
    获取数据库会话的依赖注入函数
    用于FastAPI的Depends
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def init_db():
    """
    初始化数据库，创建所有表
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("数据库表创建完成")


async def close_db():
    """
    关闭数据库连接
    """
    await engine.dispose()
    logger.info("数据库连接已关闭")
