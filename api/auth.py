"""
认证相关API接口
包括发送验证码、登录、获取用户信息等
"""
import os
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
import logging

from database.connection import get_db
from database.models import User
from auth.jwt_handler import create_access_token, get_current_user, security
from auth.verification import generate_code, save_verification_code, verify_code

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/auth", tags=["认证"])


class SendCodeRequest(BaseModel):
    """发送验证码请求"""
    phone: str = Field(..., min_length=11, max_length=11, description="手机号（11位）")


class LoginRequest(BaseModel):
    """登录请求"""
    phone: str = Field(..., min_length=11, max_length=11, description="手机号（11位）")
    code: str = Field(..., min_length=6, max_length=6, description="验证码（6位）")


class LoginResponse(BaseModel):
    """登录响应"""
    token: str
    user_id: str
    expires_in: int  # 秒


class UserInfoResponse(BaseModel):
    """用户信息响应"""
    user_id: str
    phone: str
    created_at: str
    last_login_at: str | None


@router.post("/send-code", summary="发送验证码")
async def send_verification_code(
    request: SendCodeRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    发送验证码到指定手机号
    
    开发阶段：返回固定验证码 123456
    生产环境：发送真实短信验证码
    """
    phone = request.phone
    
    # 验证手机号格式（简单验证）
    if not phone.isdigit():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="手机号格式不正确"
        )
    
    # 生成验证码
    code = generate_code()
    
    # 保存验证码到数据库
    await save_verification_code(db, phone, code)
    
    logger.info(f"验证码已发送: phone={phone}")
    
    return {
        "code": 200,
        "message": "验证码已发送",
        "data": {
            "phone": phone,
            # 开发阶段返回验证码，生产环境不返回
            "code": code if os.getenv("VERIFICATION_CODE_MOCK", "true").lower() == "true" else None
        }
    }


@router.post("/login", response_model=dict, summary="登录")
async def login(
    request: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    使用手机号和验证码登录
    
    如果用户不存在则自动创建
    返回JWT Token
    """
    phone = request.phone
    code = request.code
    
    # 验证验证码
    is_valid = await verify_code(db, phone, code)
    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="验证码错误或已过期"
        )
    
    # 查询或创建用户
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    
    if user is None:
        # 创建新用户
        user = User(phone=phone)
        db.add(user)
        await db.commit()
        await db.refresh(user)
        logger.info(f"创建新用户: phone={phone}, user_id={user.id}")
    else:
        # 更新最后登录时间
        user.last_login_at = datetime.utcnow()
        await db.commit()
        logger.info(f"用户登录: phone={phone}, user_id={user.id}")
    
    # 生成JWT Token
    token = create_access_token(str(user.id))
    expires_in = int(os.getenv("JWT_EXPIRATION_HOURS", "24")) * 3600
    
    return {
        "code": 200,
        "message": "登录成功",
        "data": {
            "token": token,
            "user_id": str(user.id),
            "expires_in": expires_in
        }
    }


@router.get("/me", response_model=dict, summary="获取当前用户信息")
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    """
    获取当前登录用户的信息
    """
    return {
        "code": 200,
        "message": "获取成功",
        "data": {
            "user_id": str(current_user.id),
            "phone": current_user.phone,
            "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
            "last_login_at": current_user.last_login_at.isoformat() if current_user.last_login_at else None
        }
    }
