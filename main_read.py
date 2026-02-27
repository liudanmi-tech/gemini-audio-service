"""
北京只读 API 入口（方案二）
仅提供读接口，无 Gemini、无上传、无策略生成。
用于中国用户提速：录音列表、详情、技能、档案、图片等读接口从北京 RDS/OSS 拉取。
"""
import os
import json
import time
import traceback
import logging
import uuid
from contextlib import asynccontextmanager
from typing import List, Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, Query, Depends, Request
from fastapi.responses import Response
from pydantic import BaseModel
from dotenv import load_dotenv
from sqlalchemy import select, func, text
from sqlalchemy.ext.asyncio import AsyncSession

# 配置日志
log_file_path = os.path.expanduser("~/gemini-audio-service-read.log")
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(log_file_path),
    ],
)
logger = logging.getLogger(__name__)

# 确保从项目根目录加载 .env（uvicorn 启动时 cwd 可能不同）
_env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
load_dotenv(_env_path)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期：仅初始化数据库，无 Gemini/代理/技能"""
    try:
        logger.info("正在初始化数据库...")
        from database.connection import init_db, close_db
        from database.connection import engine
        from sqlalchemy import text

        await init_db()
        logger.info("✅ 数据库初始化完成")

        # 初始化技能：扫描 SKILL.md 并注册/更新到数据库
        try:
            from skills.registry import initialize_skills
            from database.connection import AsyncSessionLocal
            async with AsyncSessionLocal() as skill_db:
                await initialize_skills(skill_db)
            logger.info("✅ 技能初始化完成")
        except Exception as e:
            logger.warning(f"⚠️ 技能初始化失败（不影响服务）: {e}")
        # 诊断 JWT 配置（不暴露密钥值）
        _secret = os.getenv("JWT_SECRET_KEY", "")
        _jwt_ok = bool(_secret) and _secret != "your-secret-key-here-change-in-production"
        logger.info(f"JWT 配置: {'已配置' if _jwt_ok else '使用默认值(生产请更换)'}")
        try:
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            logger.info("✅ 数据库连接池已预热")
        except Exception as e:
            logger.warning(f"连接池预热跳过: {e}")
    except Exception as e:
        logger.error(f"❌ 数据库初始化失败: {e}")
        logger.error(traceback.format_exc())
        raise
    yield
    try:
        await close_db()
        logger.info("✅ 数据库连接已关闭")
    except Exception as e:
        logger.error(f"关闭数据库连接时出错: {e}")


app = FastAPI(
    title="北京只读 API",
    description="方案二：只读接口，连接北京 RDS/OSS，用于中国用户提速",
    lifespan=lifespan,
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """请求日志"""
    start = time.time()
    logger.info(f"[Request] {request.method} {request.url.path}")
    try:
        response = await call_next(request)
        duration = time.time() - start
        logger.info(f"[Response] {request.url.path} status={response.status_code} duration={duration:.3f}s")
        return response
    except Exception as e:
        duration = time.time() - start
        logger.error(f"[Response] Exception path={request.url.path} error={e} duration={duration:.3f}s")
        raise


# 注册路由（完整路由包含 GET，写操作由客户端走新加坡）
from api.auth import router as auth_router
from api.skills import router as skills_router
from api.profiles import router as profiles_router
from api.audio_segments import router as audio_segments_router

app.include_router(auth_router)
app.include_router(skills_router)
app.include_router(profiles_router)
app.include_router(audio_segments_router)

# 数据库与认证
from database.connection import get_db, init_db, close_db
from database.models import Session, AnalysisResult, StrategyAnalysis, Profile
from auth.jwt_handler import get_current_user_id
from schemas.strategy_schemas import StrategyItem, VisualData, Call2Response

# OSS 配置（用于图片代理）
OSS_ACCESS_KEY_ID = os.getenv("OSS_ACCESS_KEY_ID")
OSS_ACCESS_KEY_SECRET = os.getenv("OSS_ACCESS_KEY_SECRET")
OSS_ENDPOINT = os.getenv("OSS_ENDPOINT")
OSS_BUCKET_NAME = os.getenv("OSS_BUCKET_NAME")
USE_OSS = os.getenv("USE_OSS", "true").lower() == "true"

oss_bucket = None
if USE_OSS and all([OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET, OSS_ENDPOINT, OSS_BUCKET_NAME]):
    try:
        import oss2
        auth = oss2.Auth(OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET)
        oss_bucket = oss2.Bucket(auth, OSS_ENDPOINT, OSS_BUCKET_NAME)
        logger.info("✅ OSS 配置成功（北京只读）")
    except Exception as e:
        logger.warning(f"OSS 初始化失败: {e}")
        USE_OSS = False
else:
    logger.info("OSS 已禁用或配置不完整")
    USE_OSS = False


# ---- 数据模型 ----
class TaskItem(BaseModel):
    session_id: str
    title: str
    start_time: str
    end_time: Optional[str] = None
    duration: int
    tags: List[str] = []
    status: str
    emotion_score: Optional[int] = None
    speaker_count: Optional[int] = None
    summary: Optional[str] = None
    cover_image_url: Optional[str] = None


class TaskDetailResponse(BaseModel):
    session_id: str
    title: str
    start_time: str
    end_time: Optional[str] = None
    duration: int
    tags: List[str] = []
    status: str
    error_message: Optional[str] = None
    emotion_score: Optional[int] = None
    speaker_count: Optional[int] = None
    dialogues: List[dict] = []
    risks: List[str] = []
    summary: Optional[str] = None
    speaker_mapping: Optional[dict] = None
    speaker_names: Optional[dict] = None
    conversation_summary: Optional[str] = None
    cover_image_url: Optional[str] = None
    created_at: str
    updated_at: str


class APIResponse(BaseModel):
    code: int
    message: str
    data: Optional[dict] = None
    timestamp: Optional[str] = None


_SKILL_ID_TO_NAME = {
    "workplace_jungle": "职场丛林",
    "education_communication": "亲子沟通",
    "family_relationship": "家庭关系",
    "brainstorm": "头脑风暴",
    "depression_prevention": "防抑郁监控",
}


def _build_legacy_skill_cards(visual_data: list, strategies: list, applied_skills: list) -> list:
    """从旧格式构造兼容的 skill_cards 结构"""
    if not visual_data and not strategies:
        return []
    skill_id = applied_skills[0]["skill_id"] if applied_skills else "unknown"
    skill_name = applied_skills[0].get("name") or _SKILL_ID_TO_NAME.get(skill_id, skill_id)

    def _to_dict(x):
        if isinstance(x, dict):
            return x
        if hasattr(x, "model_dump"):
            return x.model_dump()
        return x.__dict__ if hasattr(x, "__dict__") else {}

    v_dicts = [_to_dict(v) for v in visual_data]
    s_dicts = [_to_dict(s) for s in strategies]
    return [{
        "skill_id": skill_id,
        "skill_name": skill_name,
        "content_type": "strategy",
        "content": {"visual": v_dicts, "strategies": s_dicts},
    }]


# ---- 读接口 ----
@app.get("/api/v1/tasks/sessions")
async def get_task_list(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    date: Optional[str] = None,
    status: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取任务列表"""
    t_start = time.time()
    logger.info(f"[任务列表] user_id={user_id[:8]}... page={page}")
    try:
        query = select(Session).where(Session.user_id == uuid.UUID(user_id))
        if date:
            target_date = datetime.fromisoformat(date).date()
            query = query.where(func.date(Session.start_time) == target_date)
        if status:
            query = query.where(Session.status == status)
        query = query.order_by(Session.created_at.desc()).offset((page - 1) * page_size).limit(page_size + 1)

        result = await db.execute(query)
        sessions = result.scalars().all()
        has_more = len(sessions) > page_size
        if has_more:
            sessions = sessions[:page_size]

        session_ids = [str(s.id) for s in sessions]
        summary_map = {}
        cover_map = {}
        if session_ids:
            ar_result = await db.execute(
                select(AnalysisResult).where(AnalysisResult.session_id.in_([uuid.UUID(sid) for sid in session_ids]))
            )
            for ar in ar_result.scalars().all():
                summary_map[str(ar.session_id)] = ar.summary
            sa_result = await db.execute(
                select(StrategyAnalysis).where(StrategyAnalysis.session_id.in_([uuid.UUID(sid) for sid in session_ids]))
            )
            api_base = os.getenv("API_PUBLIC_URL", "http://123.57.29.111:8000").rstrip("/")
            for sa in sa_result.scalars().all():
                sid = str(sa.session_id)
                vd = sa.visual_data
                if isinstance(vd, list) and len(vd) > 0:
                    first_v = vd[0] if isinstance(vd[0], dict) else getattr(vd[0], "__dict__", {})
                    img_url = first_v.get("image_url") if isinstance(first_v, dict) else getattr(first_v, "image_url", None)
                    # 仅在 img_url 为真实 OSS 地址时返回封面，避免图片未上传成功时客户端请求 404
                    if img_url and isinstance(img_url, str) and ("oss" in img_url or "geminipicture" in img_url.lower()):
                        cover_map[sid] = f"{api_base}/api/v1/images/{sid}/0"

        task_items = [
            TaskItem(
                session_id=str(s.id),
                title=s.title or "",
                start_time=s.start_time.isoformat() if s.start_time else "",
                end_time=s.end_time.isoformat() if s.end_time else None,
                duration=s.duration or 0,
                tags=s.tags or [],
                status=s.status or "unknown",
                emotion_score=s.emotion_score,
                speaker_count=s.speaker_count,
                summary=summary_map.get(str(s.id)),
                cover_image_url=cover_map.get(str(s.id)),
            )
            for s in sessions
        ]
        total_elapsed = time.time() - t_start
        logger.info(f"[任务列表] 完成 total={total_elapsed:.2f}s sessions={len(task_items)}")
        return APIResponse(
            code=200,
            message="success",
            data={
                "sessions": [t.model_dump() for t in task_items],
                "pagination": {"page": page, "page_size": page_size, "has_more": has_more},
            },
            timestamp=datetime.now().isoformat(),
        )
    except Exception as e:
        logger.error(f"获取任务列表失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取列表失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}")
async def get_task_detail(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取任务详情"""
    try:
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id),
            )
        )
        db_session = result.scalar_one_or_none()
        if not db_session:
            raise HTTPException(status_code=404, detail="任务不存在")

        analysis_result_query = await db.execute(
            select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
        )
        analysis_result = analysis_result_query.scalar_one_or_none()

        dialogues = []
        risks = []
        summary = None
        speaker_mapping = None
        speaker_names = None
        conversation_summary = None

        if analysis_result:
            dialogues = analysis_result.dialogues if isinstance(analysis_result.dialogues, list) else []
            risks = analysis_result.risks or []
            summary = analysis_result.summary
            speaker_mapping = (
                analysis_result.speaker_mapping
                if isinstance(analysis_result.speaker_mapping, dict)
                else None
            )
            conversation_summary = getattr(analysis_result, "conversation_summary", None)

            transcript = []
            if getattr(analysis_result, "transcript", None):
                try:
                    transcript = (
                        json.loads(analysis_result.transcript)
                        if isinstance(analysis_result.transcript, str)
                        else (analysis_result.transcript or [])
                    )
                except Exception:
                    transcript = []
            if not transcript and getattr(analysis_result, "call1_result", None):
                call1 = analysis_result.call1_result
                if isinstance(call1, dict) and "transcript" in call1:
                    transcript = call1.get("transcript") or []

            name_to_display = {}
            self_profile_id = None
            self_display = None
            profile_rows = await db.execute(
                select(Profile.id, Profile.name, Profile.relationship_type).where(
                    Profile.user_id == uuid.UUID(user_id)
                )
            )
            for row in profile_rows.all():
                rel = getattr(row, "relationship_type", None) or (row[2] if len(row) > 2 else None)
                if rel == "自己":
                    self_profile_id = str(getattr(row, "id", row[0]))
                    name = getattr(row, "name", None) or (row[1] if len(row) > 1 else None) or "未知"
                    self_display = f"{name}（自己）"
                    if name and name.strip():
                        name_to_display[name.strip()] = self_display
                    break

            if transcript and self_profile_id and self_display:
                speaker_with_is_me = None
                for t in transcript:
                    if t.get("is_me") is True:
                        speaker_with_is_me = t.get("speaker")
                        break
                if speaker_with_is_me:
                    speaker_names = {speaker_with_is_me: self_display}
            elif speaker_mapping and not speaker_names:
                profile_ids_in_mapping = list(speaker_mapping.values())
                if profile_ids_in_mapping:
                    try:
                        profile_res = await db.execute(
                            select(Profile.id, Profile.name, Profile.relationship_type).where(
                                Profile.user_id == uuid.UUID(user_id),
                                Profile.id.in_([uuid.UUID(pid) for pid in profile_ids_in_mapping]),
                            )
                        )
                        id_to_display = {}
                        for row in profile_res.all():
                            name = row.name or "未知"
                            rel = getattr(row, "relationship_type", None) or "未知"
                            id_to_display[str(row.id)] = f"{name}（{rel}）"
                            if name and name.strip():
                                name_to_display[name.strip()] = id_to_display[str(row.id)]
                        speaker_names = {sp: id_to_display.get(pid, sp) for sp, pid in speaker_mapping.items()}
                    except Exception:
                        speaker_names = None

            def _replace_speaker_labels(text: Optional[str], names: dict) -> Optional[str]:
                if not text or not names:
                    return text
                for sp in sorted(names.keys(), key=len, reverse=True):
                    text = text.replace(sp, names[sp])
                if "Speaker_1" in names:
                    text = text.replace("用户", names["Speaker_1"])
                for alias, canonical in [("说话人0", "Speaker_0"), ("说话人1", "Speaker_1"), ("Speaker0", "Speaker_0"), ("Speaker1", "Speaker_1")]:
                    if canonical in names and alias in text:
                        text = text.replace(alias, names[canonical])
                return text

            def _replace_profile_names(text: Optional[str], name_map: dict) -> Optional[str]:
                if not text or not name_map:
                    return text
                for name in sorted(name_map.keys(), key=len, reverse=True):
                    text = text.replace(name, name_map[name])
                return text

            def _speaker_to_display(speaker_val: str, names: dict) -> str:
                if not names or not speaker_val:
                    return speaker_val
                if speaker_val in names:
                    return names[speaker_val]
                alias_map = {"说话人0": "Speaker_0", "说话人1": "Speaker_1", "Speaker0": "Speaker_0", "Speaker1": "Speaker_1"}
                canonical = alias_map.get(speaker_val)
                return names.get(canonical, speaker_val) if canonical else speaker_val

            if speaker_names:
                summary = _replace_speaker_labels(summary, speaker_names)
                conversation_summary = _replace_speaker_labels(conversation_summary, speaker_names)
                summary = _replace_profile_names(summary, name_to_display)
                conversation_summary = _replace_profile_names(conversation_summary, name_to_display)
                if dialogues:
                    new_dialogues = []
                    for d in dialogues:
                        if isinstance(d, dict) and "speaker" in d:
                            d = dict(d)
                            d["speaker"] = _speaker_to_display(d.get("speaker", ""), speaker_names)
                        new_dialogues.append(d)
                    dialogues = new_dialogues

        # 封面图：仅当策略分析首张图已上传到 OSS 时返回 URL，避免客户端请求不存在的图片导致 404
        cover_image_url = None
        sa_result = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        sa = sa_result.scalar_one_or_none()
        if sa and sa.visual_data and isinstance(sa.visual_data, list) and len(sa.visual_data) > 0:
            first_v = sa.visual_data[0] if isinstance(sa.visual_data[0], dict) else getattr(sa.visual_data[0], "__dict__", {})
            img_url = first_v.get("image_url") if isinstance(first_v, dict) else getattr(first_v, "image_url", None)
            if img_url:
                api_base = os.getenv("API_PUBLIC_URL", "http://123.57.29.111:8000").rstrip("/")
                cover_image_url = f"{api_base}/api/v1/images/{session_id}/0"

        detail = TaskDetailResponse(
            session_id=str(db_session.id),
            title=db_session.title or "",
            start_time=db_session.start_time.isoformat() if db_session.start_time else "",
            end_time=db_session.end_time.isoformat() if db_session.end_time else None,
            duration=db_session.duration or 0,
            tags=db_session.tags or [],
            status=db_session.status or "unknown",
            error_message=getattr(db_session, "error_message", None),
            emotion_score=db_session.emotion_score,
            speaker_count=db_session.speaker_count,
            dialogues=dialogues,
            risks=risks,
            summary=summary,
            speaker_mapping=speaker_mapping,
            speaker_names=speaker_names,
            conversation_summary=conversation_summary,
            cover_image_url=cover_image_url,
            created_at=db_session.created_at.isoformat() if db_session.created_at else "",
            updated_at=db_session.updated_at.isoformat() if db_session.updated_at else "",
        )
        return APIResponse(
            code=200,
            message="success",
            data=detail.model_dump(),
            timestamp=datetime.now().isoformat(),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务详情失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取详情失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}/status")
async def get_task_status(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """查询任务分析状态"""
    try:
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id),
            )
        )
        db_session = result.scalar_one_or_none()
        if not db_session:
            raise HTTPException(status_code=404, detail="任务不存在")

        status_value = db_session.status or "unknown"
        analysis_stage = getattr(db_session, "analysis_stage", None) or ""
        analysis_stage_detail = getattr(db_session, "analysis_stage_detail", None)
        if analysis_stage_detail is not None and not isinstance(analysis_stage_detail, dict):
            analysis_stage_detail = None

        stage_map = {
            "upload_done": (0.05, 170),
            "saving_audio": (0.10, 165),
            "transcribing": (0.20, 120),
            "matching_profiles": (0.90, 15),
            "strategy_scene": (0.92, 60),
            "strategy_matching": (0.94, 55),
            "strategy_matched_n": (0.96, 50),
            "strategy_executing": (0.97, 40),
            "strategy_images": (0.98, 25),
            "strategy_done": (1.0, 0),
            "gemini_analysis": (0.50, 45),
            "voiceprint": (0.90, 10),
        }
        if status_value == "failed":
            progress_val, eta = 0.0, 0
        elif status_value == "archived" and analysis_stage == "strategy_done":
            progress_val, eta = 1.0, 0
        elif status_value == "archived":
            progress_val, eta = stage_map.get(analysis_stage, (0.95, 30))
        else:
            progress_val, eta = stage_map.get(analysis_stage, (0.30, 60))

        payload = {
            "session_id": session_id,
            "status": status_value,
            "progress": progress_val,
            "estimated_time_remaining": eta,
            "analysis_stage": analysis_stage,
            "analysis_stage_detail": analysis_stage_detail,
            "updated_at": db_session.updated_at.isoformat() if db_session.updated_at else "",
        }
        if status_value == "failed" and getattr(db_session, "error_message", None):
            payload["failure_reason"] = db_session.error_message
        return APIResponse(
            code=200,
            message="success",
            data=payload,
            timestamp=datetime.now().isoformat(),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取状态失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}/strategies")
@app.post("/api/v1/tasks/sessions/{session_id}/strategies")
async def get_or_check_strategies(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    策略接口：有数据则返回；无数据则返回 need_generate，客户端应改用 writeBaseURL 请求新加坡生成。
    """
    try:
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id),
            )
        )
        if not result.scalar_one_or_none():
            raise HTTPException(status_code=404, detail="任务不存在")

        strategy_query = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        existing_strategy = strategy_query.scalar_one_or_none()

        if not existing_strategy:
            write_base = os.getenv("SINGAPORE_API_BASE", "http://47.79.254.213").rstrip("/")
            return APIResponse(
                code=200,
                message="success",
                data={
                    "need_generate": True,
                    "write_base_url": write_base,
                },
                timestamp=datetime.now().isoformat(),
            )

        visual_list = []
        for v in existing_strategy.visual_data or []:
            vdict = v if isinstance(v, dict) else (getattr(v, "__dict__", {}) or {})
            try:
                visual_list.append(VisualData(**vdict))
            except Exception:
                pass
        strategies_list = []
        for s in existing_strategy.strategies or []:
            sdict = s if isinstance(s, dict) else (getattr(s, "__dict__", {}) or {})
            try:
                strategies_list.append(StrategyItem(**sdict))
            except Exception:
                pass

        call2_result = Call2Response(visual=visual_list, strategies=strategies_list)
        result_dict = call2_result.model_dump()
        applied_skills = existing_strategy.applied_skills or []
        scene_category = existing_strategy.scene_category
        scene_confidence = existing_strategy.scene_confidence
        skill_cards_raw = getattr(existing_strategy, "skill_cards", None) or []
        if skill_cards_raw:
            result_dict["skill_cards"] = skill_cards_raw
        else:
            result_dict["skill_cards"] = _build_legacy_skill_cards(
                existing_strategy.visual_data or [],
                existing_strategy.strategies or [],
                applied_skills,
            )
        result_dict["applied_skills"] = applied_skills
        result_dict["scene_category"] = scene_category
        result_dict["scene_confidence"] = scene_confidence

        return APIResponse(
            code=200,
            message="success",
            data=result_dict,
            timestamp=datetime.now().isoformat(),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取策略失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取策略失败: {str(e)}")


@app.get("/api/v1/tasks/emotion-trend")
async def get_emotion_trend(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(30, ge=1, le=100),
):
    """获取心情趋势"""
    try:
        sa_result = await db.execute(
            select(StrategyAnalysis, Session.created_at)
            .join(Session, StrategyAnalysis.session_id == Session.id)
            .where(Session.user_id == uuid.UUID(user_id))
            .order_by(Session.created_at.desc())
            .limit(limit * 3)
        )
        rows = sa_result.all()
        points = []
        for sa, created_at in rows:
            skill_cards = getattr(sa, "skill_cards", None) or []
            for card in skill_cards:
                if isinstance(card, dict) and card.get("content_type") == "emotion":
                    content = card.get("content") or {}
                    points.append({
                        "session_id": str(sa.session_id),
                        "created_at": created_at.isoformat() if created_at else None,
                        "mood_state": content.get("mood_state", "平常心"),
                        "mood_emoji": content.get("mood_emoji", "😐"),
                        "sigh_count": content.get("sigh_count", 0),
                        "haha_count": content.get("haha_count", 0),
                        "char_count": content.get("char_count", 0),
                    })
                    break
            if len(points) >= limit:
                break
        return APIResponse(
            code=200,
            message="success",
            data={"points": points[:limit]},
            timestamp=datetime.now().isoformat(),
        )
    except Exception as e:
        logger.error(f"获取心情趋势失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取心情趋势失败: {str(e)}")


@app.get("/api/v1/sessions/major-events")
async def get_major_events(
    category: Optional[str] = Query(None, description="workplace|family|personal"),
    limit: int = Query(10, ge=1, le=50),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    获取重大事件列表：查询高置信度技能匹配、高情绪分数或含关键词的会话。
    纯数据库查询，不调用任何 AI API。
    """
    ALLOWED = {"workplace", "family", "personal"}
    if category and category not in ALLOWED:
        raise HTTPException(status_code=400, detail="category 必须为 workplace/family/personal")

    kw_list = ['晋升','表扬','认可','突破','疗愈','开心','温馨','感动',
               '成长','冲突解决','项目完成','谈判','促进','收获','里程碑']
    keyword_array = "ARRAY[" + ",".join(f"'%{kw}%'" for kw in kw_list) + "]"

    # When category is given: INNER JOIN LATERAL filters skill_executions to that category only.
    # This guarantees the displayed skill badge belongs to the requested category AND excludes
    # sessions that have no skill from that category (even if emotion score is high).
    # When no category: LEFT JOIN LATERAL keeps all sessions regardless of skill presence.
    if category:
        lateral_join = """JOIN LATERAL (
            SELECT se2.skill_id, se2.confidence_score
            FROM   skill_executions se2
            JOIN   skills sk2 ON se2.skill_id = sk2.skill_id
            WHERE  se2.session_id = s.id
            AND    sk2.category = :category
            ORDER  BY se2.confidence_score DESC NULLS LAST
            LIMIT  1
        ) se ON TRUE
        JOIN skills sk ON se.skill_id = sk.skill_id"""
    else:
        lateral_join = """LEFT JOIN LATERAL (
            SELECT se2.skill_id, se2.confidence_score
            FROM   skill_executions se2
            WHERE  se2.session_id = s.id
            ORDER  BY se2.confidence_score DESC NULLS LAST
            LIMIT  1
        ) se ON TRUE
        LEFT JOIN skills sk ON se.skill_id = sk.skill_id"""

    sql = text(f"""
        SELECT
            s.id::text          AS session_id,
            s.title,
            s.created_at,
            s.emotion_score,
            sa.scene_category   AS category,
            sa.strategies,
            ar.summary          AS ar_summary,
            se.skill_id,
            sk.name             AS skill_name,
            se.confidence_score
        FROM sessions s
        LEFT JOIN strategy_analysis sa ON s.id = sa.session_id
        LEFT JOIN analysis_results  ar ON s.id = ar.session_id
        {lateral_join}
        WHERE  s.user_id = :user_id
        AND    s.status NOT IN ('failed', 'recording', 'analyzing')
        AND (
               se.confidence_score > 0.75
            OR s.emotion_score > 70
            OR sa.strategies::text ILIKE ANY({keyword_array})
        )
        ORDER BY s.created_at DESC
        LIMIT :limit
    """)

    params: dict = {"user_id": uuid.UUID(user_id), "limit": limit}
    if category:
        params["category"] = category

    try:
        result = await db.execute(sql, params)
        rows = result.fetchall()

        events = []
        for row in rows:
            title_text = row.title or ""
            summary_text = ""

            strategies = row.strategies
            if isinstance(strategies, list) and strategies:
                first_strat = strategies[0]
                if isinstance(first_strat, dict):
                    content = (first_strat.get("content") or "").strip()
                    lines = [ln for ln in content.split("\n")
                             if ln.strip() and not ln.lstrip().startswith("#")]
                    clean = " ".join(lines).strip()
                    if clean:
                        candidate = clean
                        for sep in ["。", "！", "？", ".", "!", "?"]:
                            idx = clean.find(sep)
                            if 0 < idx < 60:
                                candidate = clean[: idx + 1]
                                break
                        title_text = candidate[:40]
                        summary_text = clean[:80] + ("…" if len(clean) > 80 else "")

            if not summary_text and row.ar_summary:
                ar = row.ar_summary.strip()
                summary_text = ar[:80] + ("…" if len(ar) > 80 else "")

            if not title_text:
                title_text = row.title or "对话记录"

            events.append({
                "session_id":       row.session_id,
                "title":            title_text,
                "summary":          summary_text,
                "created_at":       row.created_at.isoformat() if row.created_at else None,
                "skill_name":       row.skill_name,
                "confidence_score": row.confidence_score,
                "emotion_score":    row.emotion_score,
                "category":         row.category or category,
            })

        return APIResponse(
            code=200,
            message="success",
            data={"events": events, "total": len(events)},
            timestamp=datetime.now().isoformat(),
        )
    except Exception as e:
        logger.error(f"获取重大事件失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取重大事件失败: {str(e)}")


@app.get("/api/v1/images/{session_id}/{image_index}")
async def get_image(
    session_id: str,
    image_index: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """获取图片（从 OSS 代理，需 JWT）"""
    try:
        if not session_id.startswith("profile_"):
            result = await db.execute(
                select(Session).where(
                    Session.id == uuid.UUID(session_id),
                    Session.user_id == uuid.UUID(user_id),
                )
            )
            if not result.scalar_one_or_none():
                raise HTTPException(status_code=404, detail="任务不存在")

        if not USE_OSS or oss_bucket is None:
            raise HTTPException(status_code=503, detail="Image service unavailable")

        oss_key = f"images/{user_id}/{session_id}/{image_index}.png"
        image_object = oss_bucket.get_object(oss_key)
        image_data = image_object.read()

        media_type = "image/png"
        if len(image_data) >= 2 and image_data[0:2] == b"\xff\xd8":
            media_type = "image/jpeg"
        elif len(image_data) >= 4 and image_data[0:4] == b"\x89PNG":
            media_type = "image/png"

        return Response(
            content=image_data,
            media_type=media_type,
            headers={
                "Cache-Control": "public, max-age=3600",
                "Content-Disposition": f'inline; filename="image_{image_index}.png"',
            },
        )
    except HTTPException:
        raise
    except Exception as e:
        error_msg = str(e)
        if "NoSuchKey" in error_msg or "404" in error_msg:
            raise HTTPException(status_code=404, detail="Image not found")
        logger.error(f"获取图片失败: {e}")
        raise HTTPException(status_code=500, detail="Failed to fetch image")


@app.get("/health")
async def health():
    """健康检查"""
    return {"status": "ok", "mode": "read-only"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
