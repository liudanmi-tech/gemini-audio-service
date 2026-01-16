"""
数据库模型定义
使用SQLAlchemy ORM定义所有表结构
"""
from sqlalchemy import Column, String, Integer, Boolean, DateTime, ForeignKey, Text, ARRAY, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
from database.connection import Base


class User(Base):
    """用户表"""
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone = Column(String(11), unique=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    last_login_at = Column(DateTime(timezone=True))
    is_active = Column(Boolean, default=True)

    # 关系
    sessions = relationship("Session", back_populates="user", cascade="all, delete-orphan")


class Session(Base):
    """会话/任务表"""
    __tablename__ = "sessions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title = Column(String(255))
    start_time = Column(DateTime(timezone=True))
    end_time = Column(DateTime(timezone=True))
    duration = Column(Integer)  # 秒
    status = Column(String(50))  # 'processing', 'completed', 'failed', 'archived'
    emotion_score = Column(Integer)
    speaker_count = Column(Integer)
    tags = Column(ARRAY(String))
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # 关系
    user = relationship("User", back_populates="sessions")
    analysis_result = relationship("AnalysisResult", back_populates="session", uselist=False, cascade="all, delete-orphan")
    strategy_analysis = relationship("StrategyAnalysis", back_populates="session", uselist=False, cascade="all, delete-orphan")


class AnalysisResult(Base):
    """分析结果表"""
    __tablename__ = "analysis_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    dialogues = Column(JSONB, nullable=False)  # 对话内容数组
    risks = Column(ARRAY(String))  # 风险点数组
    summary = Column(Text)
    mood_score = Column(Integer)
    stats = Column(JSONB)  # 统计数据
    transcript = Column(Text)
    call1_result = Column(JSONB)  # Call #1 分析结果
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # 关系
    session = relationship("Session", back_populates="analysis_result")


class StrategyAnalysis(Base):
    """策略分析表"""
    __tablename__ = "strategy_analysis"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    visual_data = Column(JSONB, nullable=False)  # VisualData数组
    strategies = Column(JSONB, nullable=False)  # StrategyItem数组
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # 关系
    session = relationship("Session", back_populates="strategy_analysis")


class VerificationCode(Base):
    """验证码表"""
    __tablename__ = "verification_codes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone = Column(String(11), nullable=False, index=True)
    code = Column(String(6), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
