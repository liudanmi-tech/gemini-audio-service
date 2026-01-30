"""
数据库模型定义
使用SQLAlchemy ORM定义所有表结构
"""
from sqlalchemy import Column, String, Integer, Boolean, DateTime, ForeignKey, Text, ARRAY, JSON, Float
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
    error_message = Column(Text)  # 分析失败时的错误信息，供客户端展示
    emotion_score = Column(Integer)
    speaker_count = Column(Integer)
    tags = Column(ARRAY(String))
    audio_url = Column(String(500), nullable=True)   # 原音频 OSS URL，供剪切与声纹使用
    audio_path = Column(String(500), nullable=True)  # 原音频本地路径（无 OSS 时使用）
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
    speaker_mapping = Column(JSONB, nullable=True)  # Speaker_0/Speaker_1 -> profile_id 映射
    conversation_summary = Column(Text, nullable=True)  # 「谁和谁对话」总结（第二次 Gemini）
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
    applied_skills = Column(JSONB, default=[])  # 应用的技能列表 [{"skill_id": "workplace_jungle", "priority": 100}]
    scene_category = Column(String(50))  # 识别的场景类别
    scene_confidence = Column(Float)  # 场景识别置信度（与文档/迁移一致）
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # 关系
    session = relationship("Session", back_populates="strategy_analysis")


class Skill(Base):
    """技能库表"""
    __tablename__ = "skills"

    skill_id = Column(String(100), primary_key=True)
    name = Column(String(200), nullable=False)
    description = Column(Text)
    category = Column(String(50), nullable=False, index=True)  # workplace/family/education/brainstorm
    skill_path = Column(String(500), nullable=False)  # 技能目录路径，如 "skills/workplace_jungle"
    priority = Column(Integer, default=0)
    enabled = Column(Boolean, default=True, index=True)
    version = Column(String(50))
    prompt_template = Column(Text, nullable=True)  # Prompt 模板内容，落表后查表即可用，不依赖 SKILL.md
    meta_data = Column("metadata", JSONB, default={})  # 元数据：keywords、scenarios等（使用 Column name 参数避免与 SQLAlchemy 保留字段冲突）
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # 关系
    executions = relationship("SkillExecution", back_populates="skill", cascade="all, delete-orphan")


class SkillExecution(Base):
    """技能执行记录表"""
    __tablename__ = "skill_executions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    skill_id = Column(String(100), ForeignKey("skills.skill_id"), nullable=False, index=True)
    scene_category = Column(String(50))  # 识别的场景类别
    confidence_score = Column(Float)  # 场景识别置信度（与文档/迁移一致）
    execution_time_ms = Column(Integer)  # 执行耗时（毫秒）
    success = Column(Boolean, default=True)
    error_message = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # 关系
    skill = relationship("Skill", back_populates="executions")


class VerificationCode(Base):
    """验证码表"""
    __tablename__ = "verification_codes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    phone = Column(String(11), nullable=False, index=True)
    code = Column(String(6), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
    used = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class Profile(Base):
    """档案表"""
    __tablename__ = "profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    name = Column(String(100), nullable=False)
    relationship_type = Column("relationship", String(50), nullable=False)  # 自己、死党、领导等（使用 Column name 参数避免与 SQLAlchemy relationship 函数冲突）
    photo_url = Column(String(500))  # 照片URL
    notes = Column(Text)  # 备注
    audio_session_id = Column(UUID(as_uuid=True), ForeignKey("sessions.id", ondelete="SET NULL"), nullable=True)  # 关联的对话session_id
    audio_segment_id = Column(String(100))  # 音频片段ID
    audio_start_time = Column(Integer)  # 音频片段开始时间（秒）
    audio_end_time = Column(Integer)  # 音频片段结束时间（秒）
    audio_url = Column(String(500))  # 音频片段URL
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    # 关系
    user = relationship("User", backref="profiles")
    audio_session = relationship("Session", foreign_keys=[audio_session_id])
