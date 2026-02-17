"""
数据库连接配置
使用SQLAlchemy异步引擎连接PostgreSQL
"""
import os
import ssl
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

# 阿里云 RDS 连接配置
# 1. 白名单：RDS 控制台「数据安全性」→「白名单」添加应用服务器 IP
# 2. SSL：
#    - 报 pg_hba "no encryption"：必须启用 SSL，设 DATABASE_SSL=true
#    - 报 "rejected SSL upgrade"：需用 CA 证书验证，下载 RDS CA 证书并设 DATABASE_CA_CERT=/path/to/ca.pem
_ssl_env = os.getenv("DATABASE_SSL", "").lower()
_use_ssl = _ssl_env in ("true", "1", "require", "yes")
_ca_cert_path = os.path.expanduser(os.getenv("DATABASE_CA_CERT", "").strip())

connect_args = {
    "server_settings": {
        "application_name": "gemini_audio_service",
        "tcp_keepalives_idle": "600",
        "tcp_keepalives_interval": "30",
        "tcp_keepalives_count": "3",
    }
}
if _use_ssl:
    ssl_ctx = ssl.create_default_context()
    if _ca_cert_path and os.path.isfile(_ca_cert_path):
        # 使用阿里云 RDS CA 证书做 verify-ca，可解决 "rejected SSL upgrade"
        ssl_ctx.load_verify_locations(cafile=_ca_cert_path)
        ssl_ctx.check_hostname = False  # verify-ca 不校验主机名
        ssl_ctx.verify_mode = ssl.CERT_REQUIRED
        connect_args["ssl"] = ssl_ctx
        logger.info("数据库 SSL 已启用 (verify-ca, CA证书: %s)", _ca_cert_path)
    else:
        # 无 CA 证书时尝试只加密不验证
        ssl_ctx.check_hostname = False
        ssl_ctx.verify_mode = ssl.CERT_NONE
        connect_args["ssl"] = ssl_ctx
        logger.info("数据库 SSL 已启用 (仅加密，建议配置 DATABASE_CA_CERT 以使用 verify-ca)")

# 创建异步引擎
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    pool_size=20,
    max_overflow=30,
    pool_pre_ping=True,
    pool_recycle=3600,
    connect_args=connect_args
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
