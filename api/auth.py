"""
认证相关API接口
支持：手机号+验证码（旧）、邮箱+密码、Apple Sign In
"""
import os
import httpx
import bcrypt as _bcrypt
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime
import logging
from jose import jwt, JWTError

from database.connection import get_db
from database.models import User
from auth.jwt_handler import create_access_token, get_current_user, security
from auth.verification import generate_code, save_verification_code, verify_code

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/auth", tags=["认证"])


def _hash_password(password: str) -> str:
    return _bcrypt.hashpw(password.encode(), _bcrypt.gensalt()).decode()


def _verify_password(password: str, hashed: str) -> bool:
    return _bcrypt.checkpw(password.encode(), hashed.encode())

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISS = "https://appleid.apple.com"


# ──────────────────────────────────────────────
# 旧接口（手机号 + 验证码）- 保留不删
# ──────────────────────────────────────────────

class SendCodeRequest(BaseModel):
    phone: str = Field(..., min_length=11, max_length=11)


class LoginRequest(BaseModel):
    phone: str = Field(..., min_length=11, max_length=11)
    code: str = Field(..., min_length=6, max_length=6)


@router.post("/send-code", summary="发送验证码（旧接口保留）")
async def send_verification_code(
    request: SendCodeRequest,
    db: AsyncSession = Depends(get_db)
):
    phone = request.phone
    if not phone.isdigit():
        raise HTTPException(status_code=400, detail="Invalid phone number")
    code = generate_code()
    await save_verification_code(db, phone, code)
    logger.info(f"验证码已发送: phone={phone}")
    return {
        "code": 200,
        "message": "验证码已发送",
        "data": {
            "phone": phone,
            "code": code if os.getenv("VERIFICATION_CODE_MOCK", "true").lower() == "true" else None
        }
    }


@router.post("/login", response_model=dict, summary="手机号登录（旧接口保留）")
async def login(
    request: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    phone = request.phone
    code = request.code
    is_valid = await verify_code(db, phone, code)
    if not is_valid:
        raise HTTPException(status_code=400, detail="Invalid or expired code")
    result = await db.execute(select(User).where(User.phone == phone))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(phone=phone)
        db.add(user)
        await db.commit()
        await db.refresh(user)
    else:
        user.last_login_at = datetime.utcnow()
        await db.commit()
    token = create_access_token(str(user.id))
    expires_in = int(os.getenv("JWT_EXPIRATION_HOURS", "168")) * 3600
    return {
        "code": 200,
        "message": "登录成功",
        "data": {"token": token, "user_id": str(user.id), "expires_in": expires_in}
    }


# ──────────────────────────────────────────────
# 新接口：邮箱 + 密码（注册/登录合一）
# ──────────────────────────────────────────────

class EmailLoginRequest(BaseModel):
    email: str = Field(..., min_length=3, max_length=200)
    password: str = Field(..., min_length=8, max_length=100)


@router.post("/email-login", response_model=dict, summary="邮箱登录/注册")
async def email_login(
    request: EmailLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    邮箱 + 密码登录；若邮箱不存在则自动注册。
    密码至少 8 位。
    """
    email = request.email.lower().strip()
    password = request.password

    # 基本 email 格式校验
    if "@" not in email or "." not in email.split("@")[-1]:
        raise HTTPException(status_code=400, detail="Invalid email address")

    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()

    if user is None:
        # 自动注册
        hashed = _hash_password(password)
        user = User(email=email, password_hash=hashed)
        db.add(user)
        await db.commit()
        await db.refresh(user)
        logger.info(f"新用户注册: email={email}, user_id={user.id}")
    else:
        # 验证密码
        if not user.password_hash or not _verify_password(password, user.password_hash):
            raise HTTPException(status_code=401, detail="Incorrect email or password")
        user.last_login_at = datetime.utcnow()
        await db.commit()
        logger.info(f"邮箱登录: email={email}, user_id={user.id}")

    token = create_access_token(str(user.id))
    expires_in = int(os.getenv("JWT_EXPIRATION_HOURS", "168")) * 3600
    return {
        "code": 200,
        "message": "success",
        "data": {"token": token, "user_id": str(user.id), "expires_in": expires_in}
    }


# ──────────────────────────────────────────────
# 新接口：Apple Sign In
# ──────────────────────────────────────────────

class AppleLoginRequest(BaseModel):
    identity_token: str
    authorization_code: str
    full_name: str | None = None


async def _verify_apple_token(identity_token: str) -> dict:
    """验证 Apple identity token，返回 payload。"""
    bundle_id = os.getenv("APPLE_BUNDLE_ID", "")
    if not bundle_id:
        raise HTTPException(status_code=500, detail="APPLE_BUNDLE_ID not configured")

    # 从 Apple 拉 JWKS
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(APPLE_JWKS_URL)
            jwks = resp.json()
    except Exception as e:
        logger.error(f"Failed to fetch Apple JWKS: {e}")
        raise HTTPException(status_code=502, detail="Failed to contact Apple servers")

    # 用 jose 验证（options 允许没有算法头时的 fallback）
    try:
        payload = jwt.decode(
            identity_token,
            jwks,
            algorithms=["RS256"],
            audience=bundle_id,
            issuer=APPLE_ISS,
            options={"verify_at_hash": False}
        )
        return payload
    except JWTError as e:
        logger.warning(f"Apple token verification failed: {e}")
        raise HTTPException(status_code=401, detail="Invalid Apple identity token")


@router.post("/apple-login", response_model=dict, summary="Apple Sign In")
async def apple_login(
    request: AppleLoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    验证 Apple identity token，创建或找到对应用户。
    """
    payload = await _verify_apple_token(request.identity_token)
    apple_sub = payload.get("sub")
    apple_email = payload.get("email")  # Apple 只在首次授权时返回 email

    if not apple_sub:
        raise HTTPException(status_code=400, detail="Invalid Apple token payload")

    # 先按 apple_user_id 查
    result = await db.execute(select(User).where(User.apple_user_id == apple_sub))
    user = result.scalar_one_or_none()

    if user is None:
        # 新用户；若 Apple 返回了 email 则同时存 email
        user = User(apple_user_id=apple_sub, email=apple_email)
        db.add(user)
        await db.commit()
        await db.refresh(user)
        logger.info(f"Apple 新用户: apple_sub={apple_sub}, user_id={user.id}")
    else:
        # 已有用户；若首次未存 email 且现在有了则补上
        if apple_email and not user.email:
            user.email = apple_email
        user.last_login_at = datetime.utcnow()
        await db.commit()
        logger.info(f"Apple 登录: apple_sub={apple_sub}, user_id={user.id}")

    token = create_access_token(str(user.id))
    expires_in = int(os.getenv("JWT_EXPIRATION_HOURS", "168")) * 3600
    return {
        "code": 200,
        "message": "success",
        "data": {"token": token, "user_id": str(user.id), "expires_in": expires_in}
    }


# ──────────────────────────────────────────────
# 获取当前用户信息（兼容新旧）
# ──────────────────────────────────────────────

@router.get("/me", response_model=dict, summary="获取当前用户信息")
async def get_current_user_info(
    current_user: User = Depends(get_current_user)
):
    return {
        "code": 200,
        "message": "success",
        "data": {
            "user_id": str(current_user.id),
            "phone": current_user.phone,
            "email": current_user.email,
            "created_at": current_user.created_at.isoformat() if current_user.created_at else "",
            "last_login_at": current_user.last_login_at.isoformat() if current_user.last_login_at else None
        }
    }
