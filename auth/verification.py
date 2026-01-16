"""
验证码服务模块
负责验证码的生成、验证和管理
开发阶段使用模拟验证码，生产环境可集成短信服务
"""
import os
import random
from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from database.models import VerificationCode
import logging

logger = logging.getLogger(__name__)

# 从环境变量读取配置
VERIFICATION_CODE_MOCK = os.getenv("VERIFICATION_CODE_MOCK", "true").lower() == "true"
VERIFICATION_CODE_MOCK_VALUE = os.getenv("VERIFICATION_CODE_MOCK_VALUE", "123456")
VERIFICATION_CODE_EXPIRY_MINUTES = int(os.getenv("VERIFICATION_CODE_EXPIRY_MINUTES", "5"))


def generate_code() -> str:
    """
    生成6位数字验证码
    
    Returns:
        6位数字验证码字符串
    """
    if VERIFICATION_CODE_MOCK:
        # 开发阶段返回固定验证码
        logger.info(f"使用模拟验证码: {VERIFICATION_CODE_MOCK_VALUE}")
        return VERIFICATION_CODE_MOCK_VALUE
    else:
        # 生产环境生成随机验证码
        code = str(random.randint(100000, 999999))
        logger.debug(f"生成验证码: {code}")
        return code


async def save_verification_code(
    db: AsyncSession,
    phone: str,
    code: str,
    expiry_minutes: int = VERIFICATION_CODE_EXPIRY_MINUTES
) -> VerificationCode:
    """
    保存验证码到数据库
    
    Args:
        db: 数据库会话
        phone: 手机号
        code: 验证码
        expiry_minutes: 过期时间（分钟）
        
    Returns:
        VerificationCode对象
    """
    expires_at = datetime.utcnow() + timedelta(minutes=expiry_minutes)
    
    verification_code = VerificationCode(
        phone=phone,
        code=code,
        expires_at=expires_at
    )
    
    db.add(verification_code)
    await db.commit()
    await db.refresh(verification_code)
    
    logger.info(f"验证码已保存: phone={phone}, expires_at={expires_at}")
    return verification_code


async def verify_code(
    db: AsyncSession,
    phone: str,
    code: str
) -> bool:
    """
    验证验证码是否正确
    
    Args:
        db: 数据库会话
        phone: 手机号
        code: 验证码
        
    Returns:
        验证是否通过
    """
    # 查询未使用且未过期的验证码
    now = datetime.utcnow()
    result = await db.execute(
        select(VerificationCode).where(
            and_(
                VerificationCode.phone == phone,
                VerificationCode.code == code,
                VerificationCode.used == False,
                VerificationCode.expires_at > now
            )
        ).order_by(VerificationCode.created_at.desc())
    )
    verification_code = result.scalar_one_or_none()
    
    if verification_code is None:
        logger.warning(f"验证码验证失败: phone={phone}, code={code}")
        return False
    
    # 标记验证码为已使用
    verification_code.used = True
    await db.commit()
    
    logger.info(f"验证码验证成功: phone={phone}")
    return True


async def cleanup_expired_codes(db: AsyncSession):
    """
    清理过期的验证码（可选，用于定期清理）
    
    Args:
        db: 数据库会话
    """
    now = datetime.utcnow()
    result = await db.execute(
        select(VerificationCode).where(VerificationCode.expires_at < now)
    )
    expired_codes = result.scalars().all()
    
    for code in expired_codes:
        await db.delete(code)
    
    await db.commit()
    logger.info(f"已清理 {len(expired_codes)} 个过期验证码")
