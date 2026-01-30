"""
JWT Token处理模块
负责Token的生成、验证和中间件
"""
import os
import time
from types import SimpleNamespace
from datetime import datetime, timedelta
from typing import Optional, Dict, Tuple, Any
from jose import JWTError, jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from database.connection import get_db
from database.models import User
from sqlalchemy import select
import logging

logger = logging.getLogger(__name__)

# User 查询短期缓存，减少列表请求重复查库（TTL 秒）
_USER_CACHE_TTL = int(os.getenv("USER_CACHE_TTL", "90"))
_user_cache: Dict[str, Tuple[Any, float]] = {}

# 从环境变量读取配置
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-here-change-in-production")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
# 默认 168 小时（7 天），减少「过了一会儿就 401」；可按需在 .env 中覆盖
JWT_EXPIRATION_HOURS = int(os.getenv("JWT_EXPIRATION_HOURS", "168"))

# HTTP Bearer认证方案
security = HTTPBearer()


def create_access_token(user_id: str) -> str:
    """
    创建JWT访问令牌
    
    Args:
        user_id: 用户ID (UUID字符串)
        
    Returns:
        JWT Token字符串
    """
    expire = datetime.utcnow() + timedelta(hours=JWT_EXPIRATION_HOURS)
    payload = {
        "sub": user_id,  # subject (用户ID)
        "exp": expire,   # expiration time
        "iat": datetime.utcnow(),  # issued at
    }
    token = jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)
    logger.debug(f"为用户 {user_id} 创建Token")
    return token


def decode_token(token: str) -> Optional[str]:
    """
    解码JWT Token并返回用户ID
    
    Args:
        token: JWT Token字符串
        
    Returns:
        用户ID (UUID字符串)，如果Token无效返回None
    """
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            logger.warning("Token中缺少用户ID")
            return None
        return user_id
    except JWTError as e:
        logger.warning(f"Token解码失败: {e}")
        return None


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """
    从JWT Token中获取当前用户
    
    用于FastAPI的Depends，作为依赖注入使用
    
    Args:
        credentials: HTTP Bearer认证凭据
        db: 数据库会话
        
    Returns:
        User对象
        
    Raises:
        HTTPException: 如果Token无效或用户不存在
    """
    token = credentials.credentials
    user_id = decode_token(token)
    
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证令牌",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # 短期缓存：列表等接口并行请求时只查一次 User
    now = time.time()
    if user_id in _user_cache:
        cached, expiry = _user_cache[user_id]
        if now < expiry:
            if not cached.is_active:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="用户已被禁用",
                )
            return cached
    
    # 从数据库查询用户
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="用户已被禁用",
        )
    
    # 缓存脱壳后的简单对象，避免绑定 session
    snapshot = SimpleNamespace(id=user.id, is_active=user.is_active)
    _user_cache[user_id] = (snapshot, now + _USER_CACHE_TTL)
    return snapshot


async def get_current_user_id(
    current_user: User = Depends(get_current_user)
) -> str:
    """
    获取当前用户ID（UUID字符串）
    
    用于需要用户ID但不需完整User对象的场景
    
    Args:
        current_user: 当前用户对象
        
    Returns:
        用户ID字符串
    """
    return str(current_user.id)
