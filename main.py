"""
FastAPI 音频分析微服务
通过 Google Gemini API 分析上传的音频文件
"""

import os
import json
import time
import tempfile
import traceback
import logging
import uuid
import asyncio
from contextlib import asynccontextmanager
from io import BytesIO
from typing import List, Optional, Any, Tuple
from pathlib import Path
from datetime import datetime

import google.generativeai as genai
from google import genai as genai_new  # 新的 SDK 用于图片生成
from google.genai import types as genai_types
from fastapi import FastAPI, UploadFile, File, HTTPException, Query, Depends, Request
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel
from dotenv import load_dotenv
import base64

# 配置日志
# 使用用户目录下的日志文件，避免权限问题
log_file_path = os.path.expanduser('~/gemini-audio-service.log')
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(log_file_path)
    ]
)
logger = logging.getLogger(__name__)

# 加载环境变量
load_dotenv()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期：启动时初始化数据库与技能，关闭时释放连接（替代已弃用的 on_event）"""
    # === startup ===
    use_proxy = os.getenv("PROXY_FORCE_LOCALHOST", "").lower() == "true" or bool(os.getenv("PROXY_URL"))
    proxy_url = os.getenv("PROXY_URL", "http://127.0.0.1/secret-channel")
    if use_proxy and proxy_url:
        try:
            from urllib.parse import urlparse
            parsed = urlparse(proxy_url)
            host = parsed.hostname or "127.0.0.1"
            port = parsed.port or (80 if parsed.scheme == "http" else 443)
            sock = __import__("socket").socket(__import__("socket").AF_INET, __import__("socket").SOCK_STREAM)
            sock.settimeout(3)
            sock.connect((host, port))
            sock.close()
            logger.info(f"✅ 代理可达: {host}:{port}")
        except (OSError, Exception) as e:
            err = str(e).lower()
            if "refused" in err or "111" in err:
                logger.warning(
                    "⚠️ 代理连接被拒绝 (Connection refused)。录音分析上传会失败。"
                    " 请在服务器上启动 Nginx（或代理），并确保监听 %s:%s，且 /secret-channel 已配置转发到 Gemini。",
                    host, port
                )
            else:
                logger.warning(f"⚠️ 代理检测失败: {e}")
    try:
        logger.info("正在初始化数据库...")
        await init_db()
        logger.info("✅ 数据库初始化完成")
        try:
            from database.connection import engine
            from sqlalchemy import text
            async with engine.connect() as conn:
                await conn.execute(text("SELECT 1"))
            logger.info("✅ 数据库连接池已预热")
        except Exception as e:
            logger.warning(f"连接池预热跳过: {e}")
        try:
            logger.info("正在初始化技能...")
            from database.connection import AsyncSessionLocal
            async with AsyncSessionLocal() as db:
                try:
                    registered_skills = await initialize_skills(db)
                    logger.info(f"✅ 技能初始化完成，共注册 {len(registered_skills)} 个技能")
                    for skill in registered_skills:
                        logger.info(f"  - {skill['skill_id']}: {skill['name']}")
                except Exception as e:
                    logger.error(f"❌ 技能初始化失败: {e}")
                    logger.error(traceback.format_exc())
                    await db.rollback()
        except Exception as e:
            logger.error(f"❌ 技能初始化失败: {e}")
            logger.error(traceback.format_exc())
    except Exception as e:
        logger.error(f"❌ 数据库初始化失败: {e}")
        logger.error(traceback.format_exc())
    yield
    # === shutdown ===
    try:
        await close_db()
        logger.info("✅ 数据库连接已关闭")
    except Exception as e:
        logger.error(f"关闭数据库连接时出错: {e}")


# 初始化 FastAPI 应用
app = FastAPI(title="音频分析服务", description="通过 Gemini API 分析音频文件", lifespan=lifespan)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """请求/响应日志：便于排查 502 与列表接口问题"""
    start = time.time()
    is_extract = "extract-segment" in request.url.path
    if is_extract:
        logger.info(f"[Request] ===== extract-segment 收到请求 ===== {request.method} {request.url.path}")
    else:
        logger.info(f"[Request] {request.method} {request.url.path}")
    try:
        response = await call_next(request)
        duration = time.time() - start
        status = response.status_code
        if is_extract:
            logger.info(f"[Response] ===== extract-segment 返回 ===== path={request.url.path} status={status} duration={duration:.3f}s")
        else:
            logger.info(f"[Response] {request.url.path} status={status} duration={duration:.3f}s")
        if status >= 500:
            logger.error(f"[Response] 5xx path={request.url.path} status={status} duration={duration:.3f}s")
        return response
    except Exception as e:
        duration = time.time() - start
        logger.error(f"[Response] Exception path={request.url.path} error={type(e).__name__}: {e} duration={duration:.3f}s")
        logger.error(traceback.format_exc())
        if is_extract:
            logger.error(f"[Response] ===== extract-segment 发生未捕获异常 ===== 详见上方堆栈")
        raise


# 注册认证路由
from api.auth import router as auth_router
app.include_router(auth_router)

# 注册技能管理路由
from api.skills import router as skills_router
app.include_router(skills_router)

# 注册档案管理路由
from api.profiles import router as profiles_router
app.include_router(profiles_router)

# 注册音频片段路由
from api.audio_segments import router as audio_segments_router
app.include_router(audio_segments_router)

# 导入数据库相关
from database.connection import get_db, init_db, close_db
from database.models import User, Session, AnalysisResult, StrategyAnalysis, Skill, SkillExecution, Profile
from auth.jwt_handler import get_current_user_id, get_current_user
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

# 导入技能模块
from skills.router import classify_scene, match_skills
from skills.registry import get_skill, initialize_skills
from skills.executor import execute_skill

# 配置 Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PROXY_URL_RAW = os.getenv("PROXY_URL", "http://47.79.254.213/secret-channel")
USE_PROXY = os.getenv("USE_PROXY", "true").lower() == "true"
# 当应用与代理在同一台机时设为 true，可避免 Connection refused（请求走 127.0.0.1）
PROXY_FORCE_LOCALHOST = os.getenv("PROXY_FORCE_LOCALHOST", "true").lower() == "true"

if PROXY_FORCE_LOCALHOST and USE_PROXY and PROXY_URL_RAW:
    from urllib.parse import urlparse, urlunparse
    _p = urlparse(PROXY_URL_RAW)
    PROXY_URL = urlunparse((_p.scheme, "127.0.0.1" + (f":{_p.port}" if _p.port else ""), _p.path or "", _p.params, _p.query, _p.fragment))
    logger.info(f"PROXY_FORCE_LOCALHOST 已启用，代理请求使用: {PROXY_URL}")
else:
    PROXY_URL = PROXY_URL_RAW

if not GEMINI_API_KEY:
    raise ValueError("请在 .env 文件中设置 GEMINI_API_KEY")

# 策略/场景模型名，可通过环境变量覆盖（默认 gemini-3-flash-preview）
GEMINI_FLASH_MODEL = os.getenv("GEMINI_FLASH_MODEL", "gemini-3-flash-preview")

# 配置 Gemini 客户端，使用反向代理服务器
logger.info(f"API Key: {GEMINI_API_KEY[:10]}... (已隐藏)")
if USE_PROXY and PROXY_URL:
    logger.info(f"反向代理模式: 启用，代理服务器: {PROXY_URL}")
    
    # 对于反向代理，需要修改 API 的 base URL
    # google-generativeai SDK 使用 googleapiclient 和 httplib2
    try:
        from urllib.parse import urlparse, urlunparse, urljoin
        import googleapiclient.http
        import httplib2
        
        parsed = urlparse(PROXY_URL)
        logger.info(f"代理服务器主机: {parsed.hostname}, 端口: {parsed.port or 80}")
        
        # 保存原始的 execute 方法
        original_execute = googleapiclient.http.HttpRequest.execute
        
        def patched_execute(self, http=None, num_retries=0):
            """修改请求 URL，将 Google API 的 URL 替换为代理服务器 URL"""
            if http is None:
                http = self.http
            
            # 获取原始 URI
            original_uri = self.uri
            
            # 如果 URI 包含 generativelanguage.googleapis.com，替换为代理服务器
            if 'generativelanguage.googleapis.com' in original_uri:
                # 提取路径部分
                from urllib.parse import urlparse, urlunparse
                parsed_uri = urlparse(original_uri)
                
                # 构建新的 URL：使用代理服务器 + /secret-channel + 原始路径
                # 例如：https://generativelanguage.googleapis.com/v1beta/... 
                # -> http://47.79.254.213/secret-channel/v1beta/...
                new_path = f"/secret-channel{parsed_uri.path}"
                
                new_uri = urlunparse((
                    parsed.scheme,  # http
                    f"{parsed.hostname}:{parsed.port or 80}",  # 代理服务器地址
                    new_path,  # 添加 /secret-channel 前缀
                    parsed_uri.params,
                    parsed_uri.query,
                    parsed_uri.fragment
                ))
                
                logger.info(f"修改请求 URL: {original_uri} -> {new_uri}")
                self.uri = new_uri
            
            # 调用原始方法
            return original_execute(self, http, num_retries)
        
        # 替换 execute 方法
        googleapiclient.http.HttpRequest.execute = patched_execute
        logger.info("已 patch googleapiclient.http.HttpRequest.execute 以使用反向代理")
        
        # 让文件服务的 discovery 请求也走代理（否则上传时首次 discovery 可能直连 Google）
        try:
            import google.generativeai.client as _genai_client
            _genai_client.GENAI_API_DISCOVERY_URL = urlunparse((
                parsed.scheme or "http",
                f"{parsed.hostname or '127.0.0.1'}:{parsed.port or 80}",
                "/secret-channel/$discovery/rest",
                "", "", ""
            ))
            logger.info(f"已设置文件服务 discovery URL: {_genai_client.GENAI_API_DISCOVERY_URL}")
        except Exception as pe:
            logger.warning(f"设置文件服务 discovery URL 失败: {pe}")
        
    except Exception as e:
        logger.warning(f"配置反向代理时出错: {e}")
        logger.error(traceback.format_exc())
        logger.info("将尝试使用环境变量配置")
else:
    logger.info("代理模式: 禁用，直接连接 Gemini API")

# 配置 Gemini API
try:
    # 如果使用反向代理，尝试通过 client_options 设置
    config_params = {
        'api_key': GEMINI_API_KEY,
        'transport': 'rest'
    }
    
    # 尝试设置 client_options（如果 SDK 支持）
    if USE_PROXY and PROXY_URL:
        try:
            # 某些版本可能支持 client_options
            config_params['client_options'] = {
                'api_endpoint': PROXY_URL
            }
            logger.info(f"尝试通过 client_options 设置 API endpoint: {PROXY_URL}")
        except TypeError:
            logger.info("SDK 不支持 client_options，将使用其他方法")
    
    genai.configure(**config_params)
    logger.info("Gemini API 配置完成（使用 REST 传输模式）")
    
except Exception as e:
    logger.error(f"配置 Gemini API 时出错: {e}")
    raise

# 配置阿里云 OSS
OSS_ACCESS_KEY_ID = os.getenv("OSS_ACCESS_KEY_ID")
OSS_ACCESS_KEY_SECRET = os.getenv("OSS_ACCESS_KEY_SECRET")
OSS_ENDPOINT = os.getenv("OSS_ENDPOINT")
OSS_BUCKET_NAME = os.getenv("OSS_BUCKET_NAME")
OSS_CDN_DOMAIN = os.getenv("OSS_CDN_DOMAIN")  # 可选，如果使用 CDN
USE_OSS = os.getenv("USE_OSS", "true").lower() == "true"  # 是否启用 OSS

# 初始化 OSS 客户端
oss_bucket = None
if USE_OSS:
    if not all([OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET, OSS_ENDPOINT, OSS_BUCKET_NAME]):
        logger.warning("⚠️ OSS 配置不完整，将禁用 OSS 功能")
        logger.warning("需要配置: OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET, OSS_ENDPOINT, OSS_BUCKET_NAME")
        USE_OSS = False
    else:
        try:
            import oss2
            auth = oss2.Auth(OSS_ACCESS_KEY_ID, OSS_ACCESS_KEY_SECRET)
            oss_bucket = oss2.Bucket(auth, OSS_ENDPOINT, OSS_BUCKET_NAME)
            logger.info(f"✅ OSS 配置成功")
            logger.info(f"OSS Endpoint: {OSS_ENDPOINT}")
            logger.info(f"OSS Bucket: {OSS_BUCKET_NAME}")
            if OSS_CDN_DOMAIN:
                logger.info(f"OSS CDN Domain: {OSS_CDN_DOMAIN}")
        except ImportError:
            logger.error("❌ 未安装 oss2 库，请运行: pip install oss2")
            USE_OSS = False
        except Exception as e:
            logger.error(f"❌ OSS 初始化失败: {e}")
            logger.error(traceback.format_exc())
            USE_OSS = False
else:
    logger.info("OSS 功能已禁用（USE_OSS=false）")

# 定义返回数据模型
class DialogueItem(BaseModel):
    """单个对话项的数据模型"""
    speaker: str  # 说话人标识（如：说话人1、说话人A等）
    content: str  # 说话内容
    tone: str  # 说话语气（如：平静、愤怒、轻松、焦虑等）
    timestamp: Optional[str] = None  # 时间戳（格式："MM:SS"）
    is_me: Optional[bool] = False  # 是否是我说的（Speaker_1为true）

class AudioAnalysisResponse(BaseModel):
    """音频分析结果的数据模型"""
    speaker_count: int  # 说话人数
    dialogues: List[DialogueItem]  # 所有对话列表，按时间顺序
    risks: List[str]  # 风险点列表

# Call #1 数据模型（新的分析格式）
class TranscriptItem(BaseModel):
    """转录项数据模型"""
    speaker: str  # 说话人标识
    text: str  # 对话内容
    timestamp: Optional[str] = None  # 时间戳（格式："MM:SS"）
    is_me: bool  # 是否是我说的

class Call1Response(BaseModel):
    """Call #1 分析响应"""
    mood_score: int  # 情绪分数 (0-100)
    stats: dict  # 统计信息，包含 sigh 和 laugh
    summary: str  # 对话总结
    transcript: List[TranscriptItem]  # 转录列表

# Call #2 数据模型（策略分析）- 从 schemas 导入，避免与 skills 循环依赖
from schemas.strategy_schemas import StrategyItem, VisualData, Call2Response, parse_gemini_response


def wait_for_file_active(file: Any, max_wait_time=300) -> Any:
    """
    等待文件状态变为 ACTIVE
    
    Args:
        file: Gemini 文件对象
        max_wait_time: 最大等待时间（秒），默认 5 分钟
        
    Returns:
        状态为 ACTIVE 的文件对象
    """
    start_time = time.time()
    logger.info(f"[wait_for_file_active] 等待文件处理，当前状态: {file.state}")
    
    while file.state.name == "PROCESSING":
        elapsed = time.time() - start_time
        if elapsed > max_wait_time:
            raise Exception(f"文件处理超时（超过 {max_wait_time} 秒），当前状态: {file.state}")
        
        time.sleep(2)
        try:
            file = genai.get_file(file.name)
            logger.info(f"[wait_for_file_active] 文件状态: {file.state} (已等待 {int(elapsed)} 秒)")
        except Exception as e:
            logger.warning(f"[wait_for_file_active] 获取文件状态时出错: {e}")
            time.sleep(2)
            continue
    
    if file.state.name != "ACTIVE":
        raise Exception(f"文件处理失败，状态: {file.state}")
    
    return file


def upload_image_to_oss(image_bytes: bytes, user_id: str, session_id: str, image_index: int,
                        content_type: str = "image/png") -> Optional[str]:
    """
    上传图片到阿里云 OSS
    
    Args:
        image_bytes: 图片的字节数据
        user_id: 用户 ID
        session_id: 会话 ID
        image_index: 图片索引
        content_type: MIME 类型，默认 image/png
        
    Returns:
        OSS URL，如果失败返回 None
    """
    if not USE_OSS or oss_bucket is None:
        logger.warning("OSS 未启用或未初始化，无法上传图片")
        return None
    
    try:
        # 统一使用 .png 后缀便于 API 拉取
        oss_key = f"images/{user_id}/{session_id}/{image_index}.png"
        
        logger.info(f"上传图片到 OSS: {oss_key} type={content_type}")
        logger.info(f"图片大小: {len(image_bytes)} 字节")
        
        start_time = time.time()
        headers = {'Content-Type': content_type}
        oss_bucket.put_object(oss_key, image_bytes, headers=headers)
        upload_time = time.time() - start_time
        
        logger.info(f"✅ 图片上传成功，耗时: {upload_time:.2f} 秒")
        
        # 构建图片 URL
        if OSS_CDN_DOMAIN:
            # 使用 CDN 域名
            image_url = f"https://{OSS_CDN_DOMAIN}/{oss_key}"
        else:
            # 使用 OSS 直接访问 URL
            # 格式: https://{bucket}.{endpoint}/{key}
            if OSS_ENDPOINT.startswith('http://'):
                endpoint = OSS_ENDPOINT.replace('http://', 'https://')
            elif OSS_ENDPOINT.startswith('https://'):
                endpoint = OSS_ENDPOINT
            else:
                endpoint = f"https://{OSS_BUCKET_NAME}.{OSS_ENDPOINT}"
            image_url = f"{endpoint}/{oss_key}"
        
        logger.info(f"✅ 图片 URL: {image_url}")
        return image_url
        
    except Exception as e:
        logger.error(f"❌ 上传图片到 OSS 失败: {e}")
        logger.error(f"错误类型: {type(e).__name__}")
        logger.error(f"完整错误堆栈:")
        logger.error(traceback.format_exc())
        return None


# 原音频是否上传阿里云 OSS（默认 false：仅本地，直接走 Gemini）
USE_OSS_FOR_ORIGINAL_AUDIO = os.getenv("USE_OSS_FOR_ORIGINAL_AUDIO", "false").lower() == "true"


def persist_original_audio(
    session_id: str,
    temp_file_path: str,
    file_filename: str,
    user_id: str,
) -> Tuple[Optional[str], Optional[str]]:
    """
    将原音频持久化到本地（或 OSS，需显式启用），供后续剪切与声纹使用。
    默认不上传阿里云，直接走 Gemini 分析。
    Returns:
        (audio_url, audio_path): OSS 时 url 有值；仅本地时 path 有值。
    """
    audio_url: Optional[str] = None
    audio_path: Optional[str] = None
    file_ext = Path(file_filename).suffix.lower() if file_filename else ".m4a"
    if not file_ext.startswith("."):
        file_ext = "." + file_ext

    if USE_OSS_FOR_ORIGINAL_AUDIO and USE_OSS and oss_bucket is not None:
        try:
            oss_key = f"sessions/{user_id}/{session_id}/original{file_ext}"
            with open(temp_file_path, "rb") as f:
                content = f.read()
            headers = {"Content-Type": "audio/mp4" if file_ext == ".m4a" else "application/octet-stream"}
            oss_bucket.put_object(oss_key, content, headers=headers)
            if OSS_CDN_DOMAIN:
                audio_url = f"https://{OSS_CDN_DOMAIN}/{oss_key}"
            else:
                if OSS_ENDPOINT.startswith("http://"):
                    endpoint = OSS_ENDPOINT.replace("http://", "https://")
                elif OSS_ENDPOINT.startswith("https://"):
                    endpoint = OSS_ENDPOINT
                else:
                    endpoint = f"https://{OSS_BUCKET_NAME}.{OSS_ENDPOINT}"
                audio_url = f"{endpoint}/{oss_key}"
            logger.info(f"[分析-{session_id}] 原音频已上传 OSS: {audio_url[:80]}...")
        except Exception as e:
            logger.warning(f"原音频上传 OSS 失败，将使用本地路径: {e}")
            audio_url = None

    if not audio_url:
        # 本地存储（默认路径，供剪切与声纹使用）
        storage_dir = os.getenv("AUDIO_STORAGE_DIR", "data/audio/sessions")
        os.makedirs(storage_dir, exist_ok=True)
        local_name = f"{session_id}{file_ext}"
        dest_path = os.path.join(storage_dir, local_name)
        try:
            import shutil
            shutil.copy2(temp_file_path, dest_path)
            audio_path = dest_path
            logger.info(f"[分析-{session_id}] 原音频已保存到本地: {audio_path}")
        except Exception as e:
            logger.warning(f"原音频保存本地失败: {e}")

    return (audio_url, audio_path)


def _fetch_image_bytes(url: str, timeout: float = 10.0) -> Optional[Tuple[bytes, str]]:
    """
    从 URL 下载图片，返回 (bytes, mime_type) 或 None。
    支持 http/https，用于获取档案照片作为图片生成参考。
    注意：/api/v1/images/ 需 JWT，服务端内部请用 _fetch_profile_image_from_oss。
    """
    if not url or not isinstance(url, str) or not url.strip():
        return None
    url = url.strip()
    if not url.startswith(("http://", "https://")):
        return None
    try:
        from urllib.request import Request, urlopen
        req = Request(url, headers={"User-Agent": "gemini-audio-service/1.0"})
        with urlopen(req, timeout=timeout) as resp:
            data = resp.read()
            ctype = resp.headers.get("Content-Type", "").split(";")[0].strip().lower()
            if "png" in ctype:
                mime = "image/png"
            elif "webp" in ctype:
                mime = "image/webp"
            else:
                mime = "image/jpeg"
            if len(data) > 7 * 1024 * 1024:  # 7MB limit for Gemini inline
                logger.warning(f"[档案照片] 图片过大 ({len(data)} bytes)，跳过")
                return None
            return (data, mime)
    except Exception as e:
        logger.warning(f"[档案照片] 下载失败 url={url[:80]}...: {e}")
        return None


def _fetch_profile_image_from_oss(user_id: str, profile_id: str) -> Optional[Tuple[bytes, str]]:
    """
    从 OSS 直接读取档案照片，用于图片生成参考（避免 API 需 JWT 的问题）。
    路径: images/{user_id}/profile_{profile_id}/0.png
    """
    if not USE_OSS or oss_bucket is None:
        return None
    try:
        oss_key = f"images/{user_id}/profile_{profile_id}/0.png"
        obj = oss_bucket.get_object(oss_key)
        data = obj.read()
        if len(data) > 7 * 1024 * 1024:
            logger.warning(f"[档案照片] OSS 图片过大 ({len(data)} bytes)，跳过")
            return None
        if len(data) >= 2 and data[0:2] == b"\xff\xd8":
            mime = "image/jpeg"
        elif len(data) >= 4 and data[0:4] == b"\x89PNG":
            mime = "image/png"
        else:
            mime = "image/jpeg"
        return (data, mime)
    except Exception as e:
        logger.debug(f"[档案照片] OSS 读取失败 profile_id={profile_id}: {e}")
        return None


async def _get_profile_reference_images(session_id: str, user_id: str, db: AsyncSession) -> List[Tuple[bytes, str]]:
    """
    根据 speaker_mapping 获取左右人物（用户/对方）的档案照片，用于图片生成参考。
    优先从 OSS 直接读取（路径 images/{user_id}/profile_{id}/0.png），避免 API 需 JWT。
    返回 [(left_bytes, mime), (right_bytes, mime), ...]，顺序为左侧（用户）、右侧（对方）。
    """
    result = []
    try:
        ar_q = await db.execute(
            select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
        )
        ar = ar_q.scalar_one_or_none()
        if not ar or not isinstance(getattr(ar, "speaker_mapping", None), dict):
            logger.info(f"[档案照片] session_id={session_id} 无 speaker_mapping，无法获取参考图")
            return result
        speaker_mapping = ar.speaker_mapping
        profile_ids = [str(pid) for pid in speaker_mapping.values()]
        if not profile_ids:
            logger.info(f"[档案照片] session_id={session_id} speaker_mapping 为空")
            return result
        logger.info(f"[档案照片] speaker_mapping={speaker_mapping} profile_ids={profile_ids}")
        
        prof_q = await db.execute(
            select(Profile).where(
                Profile.user_id == uuid.UUID(user_id),
                Profile.id.in_([uuid.UUID(pid) for pid in profile_ids])
            )
        )
        profiles = {str(p.id): p for p in prof_q.scalars().all()}
        left_pid, right_pid = None, None
        for sp, pid in speaker_mapping.items():
            pid_str = str(pid)
            if pid_str not in profiles:
                continue
            rel = getattr(profiles[pid_str], "relationship_type", "") or ""
            if rel == "自己":
                left_pid = pid_str
            else:
                right_pid = pid_str
        if not left_pid and profile_ids:
            left_pid = next((p for p in profile_ids if p in profiles), None)
        if not right_pid and len(profiles) >= 2 and left_pid:
            right_pid = next((p for p in profile_ids if p in profiles and p != left_pid), None)
        
        for pid in [left_pid, right_pid]:
            if not pid:
                continue
            p = profiles.get(pid)
            if not p:
                continue
            photo_url = getattr(p, "photo_url", None)
            fetched = None
            # 优先从 OSS 直接读取（不依赖 JWT，且档案上传后 OSS 必有文件）
            if USE_OSS and oss_bucket:
                fetched = _fetch_profile_image_from_oss(user_id, pid)
            if not fetched and photo_url and photo_url.startswith(("http://", "https://")):
                # 若为直连 OSS CDN 等公开 URL，可尝试 HTTP 拉取（/api/v1/images 需 JWT 会失败）
                if "/api/v1/images/" not in photo_url:
                    fetched = _fetch_image_bytes(photo_url)
            if fetched:
                result.append(fetched)
                logger.info(f"[档案照片] 已加载参考图: profile_id={pid} name={getattr(p,'name','')} rel={getattr(p,'relationship_type','')}")
            else:
                logger.warning(f"[档案照片] 无法加载 profile_id={pid} photo_url={bool(photo_url)} OSS={USE_OSS and oss_bucket is not None}")
    except Exception as e:
        logger.warning(f"[档案照片] 获取参考图失败: {e}", exc_info=True)
    return result


def generate_image_from_prompt(
    image_prompt: str,
    user_id: str,
    session_id: str,
    image_index: int,
    reference_images: Optional[List[Tuple[bytes, str]]] = None,
    max_retries: int = 3,
) -> Optional[str]:
    """
    使用 Gemini Nano Banana 生成图片并上传到 OSS。
    支持多模态输入：可传入档案照片作为参考图，提升人物一致性。
    
    Args:
        image_prompt: 图片生成提示词
        user_id: 用户 ID
        session_id: 会话 ID
        image_index: 图片索引
        reference_images: 可选，参考图列表 [(bytes, mime_type), ...]，最多2张（左=用户，右=对方）
        max_retries: 最大重试次数
        
    Returns:
        图片 URL 或 Base64，失败返回 None
    """
    from google.genai.errors import ClientError
    
    client = genai_new.Client(api_key=GEMINI_API_KEY)
    
    config = genai_types.GenerateContentConfig(
        image_config=genai_types.ImageConfig(aspect_ratio="4:3")
    )
    
    # 构建 contents：参考图 + 文本 prompt
    style_prefix = "宫崎骏吉卜力动画风格，温暖自然色调，柔和笔触。"
    if reference_images and len(reference_images) >= 1:
        ref_desc = "第一张图为左侧人物（用户）的参考照片"
        if len(reference_images) >= 2:
            ref_desc += "，第二张图为右侧人物（对方）的参考照片"
        ref_desc += "。请保持人物面部与气质与参考图一致。\n\n"
        full_prompt = style_prefix + ref_desc + image_prompt
    else:
        full_prompt = style_prefix + image_prompt
    
    contents_list = []
    if reference_images:
        for img_bytes, mime_type in reference_images[:2]:  # 最多2张
            contents_list.append(genai_types.Part.from_bytes(data=img_bytes, mime_type=mime_type))
        logger.info(f"[图片生成] 使用 {len(contents_list)} 张档案照片作为参考图")
    contents_list.append(full_prompt)
    
    for attempt in range(max_retries):
        try:
            if attempt > 0:
                logger.info(f"========== 重试生成图片 (第 {attempt + 1}/{max_retries} 次) ==========")
            else:
                logger.info(f"========== 开始生成图片 ==========")
            
            logger.info(f"提示词长度: {len(full_prompt)} 字符 (含参考图说明)")
            logger.debug(f"提示词内容: {full_prompt[:200]}...")
            logger.info(f"调用模型: gemini-2.5-flash-image 参考图数={len(reference_images) if reference_images else 0}")
            
            start_time = time.time()
            response = client.models.generate_content(
                model="gemini-2.5-flash-image",
                contents=contents_list,
                config=config
            )
            generate_time = time.time() - start_time
            
            logger.info(f"✅ 图片生成成功，耗时: {generate_time:.2f} 秒")
            
            # 提取图片数据
            image_bytes = None
            for part in response.parts:
                if part.inline_data is not None:
                    # 图片数据已经是 bytes
                    image_bytes = part.inline_data.data
                    logger.info(f"✅ 图片数据提取成功，大小: {len(image_bytes)} 字节")
                    break
            
            if image_bytes is None:
                logger.warning("⚠️ 响应中没有找到图片数据")
                return None
            
            # 尝试上传到 OSS
            if USE_OSS and oss_bucket is not None:
                logger.info(f"尝试上传图片到 OSS...")
                image_url = upload_image_to_oss(image_bytes, user_id, session_id, image_index)
                if image_url:
                    logger.info(f"✅ 图片已上传到 OSS，URL: {image_url}")
                    return image_url
                else:
                    logger.warning("⚠️ OSS 上传失败，降级到 Base64")
            
            # 如果 OSS 未启用或上传失败，降级到 Base64
            logger.info("使用 Base64 编码返回图片")
            image_base64 = base64.b64encode(image_bytes).decode('utf-8')
            logger.info(f"✅ 图片 Base64 编码完成，大小: {len(image_base64)} 字符")
            return image_base64
            
        except ClientError as e:
            error_code = getattr(e, 'status_code', None)
            error_message = str(e)
            
            # 处理 429 配额超限错误
            if error_code == 429 or '429' in error_message or 'RESOURCE_EXHAUSTED' in error_message:
                # 尝试从错误信息中提取重试延迟
                retry_delay = 15  # 默认延迟 15 秒
                if 'retry in' in error_message.lower() or 'retryDelay' in error_message:
                    import re
                    delay_match = re.search(r'retry in ([\d.]+)s', error_message, re.IGNORECASE)
                    if delay_match:
                        retry_delay = max(15, int(float(delay_match.group(1))) + 2)  # 至少等待 15 秒，多加 2 秒缓冲
                
                logger.warning(f"⚠️ 配额超限 (429)，等待 {retry_delay} 秒后重试...")
                logger.warning(f"错误详情: {error_message[:500]}")
                
                # 检查是否是免费层配额为 0 的问题
                if 'limit: 0' in error_message or 'free_tier' in error_message.lower():
                    logger.error("❌ 检测到免费层配额限制 (limit: 0)")
                    logger.error("💡 建议检查:")
                    logger.error("   1. 确认 API Key 是否关联到付费项目")
                    logger.error("   2. 在 Google Cloud Console 检查配额设置")
                    logger.error("   3. 确认已启用图片生成 API 的付费配额")
                    logger.error("   4. 可能需要等待几分钟让配额刷新")
                
                if attempt < max_retries - 1:
                    logger.info(f"等待 {retry_delay} 秒后重试...")
                    time.sleep(retry_delay)
                    continue
                else:
                    logger.error(f"❌ 重试 {max_retries} 次后仍然失败，放弃生成图片")
                    logger.error(f"最终错误: {error_message[:500]}")
                    return None
            else:
                # 其他类型的 ClientError
                logger.error(f"❌ 生成图片失败 (ClientError): {error_code} - {error_message[:500]}")
                if attempt < max_retries - 1:
                    wait_time = (attempt + 1) * 5  # 指数退避：5秒、10秒、15秒
                    logger.info(f"等待 {wait_time} 秒后重试...")
                    time.sleep(wait_time)
                    continue
                else:
                    logger.error(traceback.format_exc())
                    return None
                    
        except Exception as e:
            logger.error(f"❌ 生成图片失败: {e}")
            logger.error(f"错误类型: {type(e).__name__}")
            if attempt < max_retries - 1:
                wait_time = (attempt + 1) * 5  # 指数退避
                logger.info(f"等待 {wait_time} 秒后重试...")
                time.sleep(wait_time)
                continue
            else:
                logger.error(f"完整错误堆栈:")
                logger.error(traceback.format_exc())
                return None
    
    return None


# 大文件分片阈值：超过此大小时切分为多个 ≤18MB 片段分别上传 Gemini
CHUNK_SIZE_MB = 18.0


def _upload_single_file_to_gemini(
    path: str,
    display_name: str,
    _sid: str,
    no_proxy: bool,
    use_resumable: bool,
    upload_timeout: int,
    max_retries: int = 3,
):
    """上传单个文件到 Gemini，带重试。返回 uploaded_file 对象。"""
    import concurrent.futures
    retry_count = 0
    current_resumable = use_resumable
    while retry_count < max_retries:
        try:
            logger.info(f"[分析-{_sid}-step3] 尝试上传（第 {retry_count + 1}/{max_retries} 次，resumable={current_resumable}，超时={upload_timeout}s）...")
            start_upload = time.time()
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as ex:
                fut = ex.submit(
                    genai.upload_file,
                    path=path,
                    display_name=display_name,
                    resumable=current_resumable,
                )
                try:
                    uploaded_file = fut.result(timeout=upload_timeout)
                except concurrent.futures.TimeoutError:
                    raise Exception(f"Gemini 文件上传超时（{upload_timeout}秒）")
            logger.info(f"[分析-{_sid}-step4] ✅ 文件上传成功！name={uploaded_file.name} 耗时={time.time()-start_upload:.2f}s")
            return uploaded_file
        except Exception as e:
            retry_count += 1
            error_msg = str(e)
            logger.error(f"[分析-{_sid}-step3] ❌ 上传失败（第 {retry_count}/{max_retries}）{error_msg}")
            if ("string indices must be integers" in error_msg or "not 'str'" in error_msg) and current_resumable:
                current_resumable = False
                retry_count -= 1
            if retry_count >= max_retries:
                raise Exception(f"上传文件失败（已重试 {max_retries} 次）: {error_msg}")
            time.sleep(5)


async def analyze_audio_from_path(temp_file_path: str, file_filename: str, session_id: Optional[str] = None) -> Tuple[AudioAnalysisResponse, Optional[Call1Response]]:
    """
    从文件路径分析音频文件（内部函数）
    若文件 > 18MB，自动切分为多个 ≤18MB 片段，分别上传 Gemini 后合并分析。
    
    Args:
        temp_file_path: 临时文件路径
        file_filename: 文件名
        
    Returns:
        元组：(AudioAnalysisResponse, Optional[Call1Response])
    """
    uploaded_file = None
    uploaded_files_list: List[Any] = []
    chunk_paths_to_clean: List[str] = []
    _sid = session_id or "?"
    
    try:
        logger.info(f"[分析-{_sid}-step1] ========== 文件上传处理开始 ==========")
        logger.info(f"[分析-{_sid}-step1] 文件已保存到临时路径: {temp_file_path}")
        
        file_size = os.path.getsize(temp_file_path)
        file_size_mb = file_size / 1024 / 1024
        logger.info(f"[分析-{_sid}-step2] 文件名: {file_filename} 大小: {file_size} 字节 ({file_size_mb:.2f} MB)")
        
        no_proxy = os.getenv("GEMINI_FILE_UPLOAD_NO_PROXY", "").lower() == "true"
        use_resumable = False if no_proxy else True
        _genai_client = None
        _old_discovery_url = None
        if no_proxy:
            try:
                import google.generativeai.client as _genai_client
                _old_discovery_url = getattr(_genai_client, "GENAI_API_DISCOVERY_URL", None)
                _genai_client.GENAI_API_DISCOVERY_URL = "https://generativelanguage.googleapis.com/$discovery/rest"
                logger.info("文件上传已切换为直连 Gemini（GEMINI_FILE_UPLOAD_NO_PROXY=true）")
            except Exception as e:
                logger.warning(f"切换直连失败: {e}，将继续使用代理")
        
        upload_timeout = int(os.getenv("GEMINI_UPLOAD_TIMEOUT", "90"))
        
        try:
            if file_size > CHUNK_SIZE_MB * 1024 * 1024:
                # 大文件：切分为多个 ≤18MB 片段，分别上传后一起传给 Gemini
                from utils.audio_storage import split_audio_into_chunks
                logger.info(f"[分析-{_sid}] 大文件（{file_size_mb:.1f} MB > {CHUNK_SIZE_MB} MB），切分后多文件上传")
                chunks = split_audio_into_chunks(
                    temp_file_path,
                    max_chunk_mb=CHUNK_SIZE_MB,
                    base_name=f"gemini_{_sid[:8]}",
                )
                chunk_paths_to_clean = [c[2] for c in chunks]
                for i, (start_sec, end_sec, chunk_path) in enumerate(chunks):
                    chunk_name = f"{file_filename}_片段{i+1}"
                    uf = _upload_single_file_to_gemini(
                        chunk_path, chunk_name, _sid, no_proxy, use_resumable, upload_timeout
                    )
                    uf = wait_for_file_active(uf, max_wait_time=600)
                    uploaded_files_list.append(uf)
                # 多文件时用统一变量，后续 generate_content 用 contents
                uploaded_file = uploaded_files_list[0] if uploaded_files_list else None
            else:
                # 小文件：单文件上传
                logger.info(f"[分析-{_sid}-step2] ========== 开始上传文件到 Gemini ==========")
                uploaded_file = _upload_single_file_to_gemini(
                    temp_file_path, file_filename, _sid, no_proxy, use_resumable, upload_timeout
                )
                logger.info(f"[分析-{_sid}-step5] 等待文件处理完成，当前状态: {uploaded_file.state}")
                uploaded_file = wait_for_file_active(uploaded_file, max_wait_time=600)
        finally:
            if no_proxy and _genai_client is not None and _old_discovery_url is not None:
                try:
                    _genai_client.GENAI_API_DISCOVERY_URL = _old_discovery_url
                    logger.info("已恢复文件服务 discovery URL")
                except Exception:
                    pass
        
        logger.info(f"[分析-{_sid}-step6] ✅ 文件 ACTIVE，即将调用 generate_content")
        
        model_name = GEMINI_FLASH_MODEL
        model = genai.GenerativeModel(model_name)
        
        # 单文件 / 多文件 共用基础提示词
        prompt_base = """角色: 你是一个专业的语音分析与行为观察专家。

任务: 请深入解析上传的音频文件，并输出严格格式化的 JSON 数据。

参数定义:

1. **mood_score**: (Integer, 0-100) 根据语调波动、语速变化及语义冲突程度对对话氛围进行建模评分。分数越高表示氛围越轻松愉快。

2. **sigh_count**: (Integer) 识别并统计 Speaker_1 (用户) 在音频中产生的长呼气或叹气次数（通常代表压力、疲惫或无奈）。

3. **laugh_count**: (Integer) 识别并统计全场出现的所有类型笑声（包括愉快的、尴尬的或嘲讽的笑）。

4. **summary**: (String) 对对话内容、核心矛盾及情绪转折点进行精炼总结（100-200字）。

5. **transcript**: (Array) 按时间顺序包含所有对话，每个对话包含：
   - speaker: 说话人标识（如：Speaker_0, Speaker_1，其中Speaker_1为用户）
   - text: 对话内容（完整原话）
   - timestamp: 时间戳（格式："MM:SS"，如"00:01"）
   - is_me: (Boolean) 是否为用户说的（Speaker_1为true，其他为false）

6. **risks**: (Array) 关键风险点列表

请务必以纯 JSON 格式返回，不要包含 Markdown 标记。

返回格式必须严格遵循以下结构：
{
  "mood_score": 75,
  "sigh_count": 2,
  "laugh_count": 5,
  "summary": "对话气氛整体缓和，但在周末加班的截止日期问题上存在明显的隐形拉锯，用户试图防御个人时间。",
  "transcript": [
    {
      "speaker": "Speaker_0",
      "text": "具体说话内容",
      "timestamp": "00:01",
      "is_me": false
    },
    {
      "speaker": "Speaker_1",
      "text": "具体说话内容",
      "timestamp": "00:05",
      "is_me": true
    }
  ],
  "risks": ["风险点1", "风险点2", ...]
}

注意：transcript 数组必须包含所有对话，按时间顺序排列，不要遗漏任何对话。"""
        
        if len(uploaded_files_list) > 1:
            # 多文件时附加说明
            multi_instruction = f"""
重要：你收到的是同一段录音按时间顺序切分的 {len(uploaded_files_list)} 个连续片段（片段1、2、...、{len(uploaded_files_list)}）。
请将全部片段作为整体分析，合并输出一个完整的 JSON。
transcript 中的 timestamp 必须使用相对于整段录音开始的全局时间。
例如，若片段2对应原录音的 20:00–40:00，则片段2中「00:05」的对话应记为「20:05」。"""
            prompt = prompt_base + multi_instruction
        else:
            prompt = prompt_base
        
        # 调用模型进行分析（添加重试机制）
        logger.info(f"========== 开始调用 Gemini 模型分析音频 ==========")
        logger.info(f"模型: {model_name} 文件数: {len(uploaded_files_list) or 1}")
        max_retries = 3
        retry_count = 0
        response = None
        contents = (uploaded_files_list if uploaded_files_list else [uploaded_file]) + [prompt]
        
        while retry_count < max_retries:
            try:
                logger.info(f"[分析-{_sid}-step7] 调用 generate_content（第 {retry_count + 1}/{max_retries} 次）...")
                start_generate = time.time()
                response = model.generate_content(contents)
                generate_time = time.time() - start_generate
                logger.info(f"[分析-{_sid}-step8] ✅ generate_content 成功，耗时: {generate_time:.2f}s 响应长度: {len(response.text)}")
                break
            except Exception as e:
                retry_count += 1
                error_msg = str(e)
                error_type = type(e).__name__
                logger.error(f"[分析-{_sid}-step7] ❌ generate_content 失败（第 {retry_count}/{max_retries}）{error_type}: {error_msg}")
                logger.error(f"完整错误堆栈:")
                logger.error(traceback.format_exc())
                if retry_count >= max_retries:
                    raise Exception(f"调用模型失败（重试 {max_retries} 次）: {error_msg}")
                logger.info(f"等待 5 秒后重试...")
                time.sleep(5)
        
        logger.info(f"Gemini 响应长度: {len(response.text)} 字符")
        logger.debug(f"Gemini 响应内容: {response.text[:500]}...")  # 只记录前500字符
        
        # 解析响应
        analysis_data = parse_gemini_response(response.text)
        
        # 尝试解析新的Call1格式，如果失败则使用旧格式
        call1_result = None
        try:
            # 解析转录列表
            transcript_list = []
            if "transcript" in analysis_data:
                for item in analysis_data["transcript"]:
                    transcript_list.append(TranscriptItem(
                        speaker=item.get("speaker", "未知"),
                        text=item.get("text", ""),
                        timestamp=item.get("timestamp"),
                        is_me=item.get("is_me", False)
                    ))
            
            # 构建Call1Response
            call1_result = Call1Response(
                mood_score=analysis_data.get("mood_score", 70),
                stats={
                    "sigh": analysis_data.get("sigh_count", 0),
                    "laugh": analysis_data.get("laugh_count", 0)
                },
                summary=analysis_data.get("summary", ""),
                transcript=transcript_list
            )
            
            # 转换为旧格式以保持兼容性
            dialogues_list = []
            for item in transcript_list:
                dialogues_list.append(DialogueItem(
                    speaker=item.speaker,
                    content=item.text,
                    tone="未知",  # 新格式不包含tone，保留默认值
                    timestamp=item.timestamp,
                    is_me=item.is_me
                ))
            
            speaker_count = len(set(item.speaker for item in transcript_list)) if transcript_list else 0
            
        except Exception as e:
            logger.warning(f"解析新格式失败，使用旧格式: {e}")
            # 兼容旧格式
            dialogues_list = []
            if "dialogues" in analysis_data:
                for dialogue in analysis_data["dialogues"]:
                    dialogues_list.append(DialogueItem(
                        speaker=dialogue.get("speaker", "未知"),
                        content=dialogue.get("content", ""),
                        tone=dialogue.get("tone", "未知"),
                        timestamp=dialogue.get("timestamp"),
                        is_me=dialogue.get("is_me", False)
                    ))
            speaker_count = analysis_data.get("speaker_count", 0)
        
        # 验证并构建返回数据
        result = AudioAnalysisResponse(
            speaker_count=speaker_count,
            dialogues=dialogues_list,
            risks=analysis_data.get("risks", [])
        )
        
        # 返回结果和Call1数据（如果存在）
        return result, call1_result
        
    except Exception as e:
        error_msg = str(e)
        error_type = type(e).__name__
        logger.error(f"[分析-{_sid}] ❌ analyze_audio_from_path 异常: {error_type}: {error_msg}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"音频分析失败: {error_msg}")
    
    finally:
        # 删除 Gemini 上的文件
        to_delete = uploaded_files_list if uploaded_files_list else ([uploaded_file] if uploaded_file else [])
        for uf in to_delete:
            if uf:
                try:
                    genai.delete_file(uf.name)
                    logger.info(f"已删除 Gemini 文件: {uf.name}")
                except Exception as e:
                    logger.error(f"删除 Gemini 文件失败: {e}")
        # 删除分片临时文件
        for p in chunk_paths_to_clean:
            try:
                if os.path.exists(p):
                    os.unlink(p)
                    logger.info(f"已删除分片临时文件: {p}")
            except Exception as e:
                logger.warning(f"删除分片临时文件失败: {e}")


@app.post("/analyze-audio", response_model=AudioAnalysisResponse)
async def analyze_audio(file: UploadFile = File(...)):
    """
    分析上传的音频文件
    
    Args:
        file: 上传的音频文件（mp3/wav/m4a）
        
    Returns:
        结构化的音频分析结果
    """
    # 验证文件类型
    allowed_extensions = {'.mp3', '.wav', '.m4a'}
    file_ext = Path(file.filename).suffix.lower() if file.filename else '.m4a'
    
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的文件类型。仅支持: {', '.join(allowed_extensions)}"
        )
    
    # 创建临时文件保存上传的音频
    temp_file_path = None
    
    try:
        # 保存上传的文件到临时目录
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as temp_file:
            temp_file_path = temp_file.name
            content = await file.read()
            temp_file.write(content)
        
        # 调用内部函数分析（只返回旧格式以保持API兼容性）
        result, _ = await analyze_audio_from_path(temp_file_path, file.filename or "audio.m4a")
        return result
        
    except Exception as e:
        error_msg = str(e)
        error_type = type(e).__name__
        logger.error(f"========== 处理过程中发生错误 ==========")
        logger.error(f"错误类型: {error_type}")
        logger.error(f"错误信息: {error_msg}")
        logger.error(f"完整错误堆栈:")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"音频分析失败: {error_msg}")
    
    finally:
        # 清理临时文件
        if temp_file_path and os.path.exists(temp_file_path):
            try:
                os.unlink(temp_file_path)
                print(f"已删除临时文件: {temp_file_path}")
            except Exception as e:
                print(f"删除临时文件失败: {e}")


@app.get("/")
async def root():
    """根路径，返回服务信息"""
    return {
        "service": "音频分析服务",
        "version": "1.0.0",
        "endpoint": "/analyze-audio"
    }


@app.get("/health")
async def health_check():
    """健康检查接口"""
    return {"message": "音频分析服务正在运行", "status": "ok"}


# ==================== 任务管理 API ====================

# 内存存储（临时，后续改为数据库）
tasks_storage: dict = {}
analysis_storage: dict = {}


class TaskItem(BaseModel):
    """任务项数据模型"""
    session_id: str
    title: str
    start_time: str
    end_time: Optional[str] = None
    duration: int
    tags: List[str] = []
    status: str
    emotion_score: Optional[int] = None
    speaker_count: Optional[int] = None
    summary: Optional[str] = None  # 对话总结，来自 AnalysisResult
    cover_image_url: Optional[str] = None  # 策略分析首图 URL，来自 StrategyAnalysis.visual_data[0]


class TaskListResponse(BaseModel):
    """任务列表响应"""
    sessions: List[TaskItem]
    pagination: dict


class TaskDetailResponse(BaseModel):
    """任务详情响应"""
    session_id: str
    title: str
    start_time: str
    end_time: Optional[str] = None
    duration: int
    tags: List[str] = []
    status: str
    error_message: Optional[str] = None  # 分析失败时的错误信息
    emotion_score: Optional[int] = None
    speaker_count: Optional[int] = None
    dialogues: List[dict] = []
    risks: List[str] = []
    summary: Optional[str] = None  # 对话总结
    speaker_mapping: Optional[dict] = None  # Speaker_0/1 -> profile_id
    speaker_names: Optional[dict] = None  # Speaker_0/1 -> 档案名（关系），如 张三（自己），便于前端展示
    conversation_summary: Optional[str] = None  # 「谁和谁对话」总结
    created_at: str
    updated_at: str


class UploadResponse(BaseModel):
    """上传响应"""
    session_id: str
    audio_id: str
    title: str
    status: str
    estimated_duration: Optional[int] = None
    created_at: str


class APIResponse(BaseModel):
    """通用 API 响应"""
    code: int
    message: str
    data: Optional[dict] = None
    timestamp: Optional[str] = None


def calculate_emotion_score(result: AudioAnalysisResponse) -> int:
    """计算情绪分数"""
    score = 70  # 基础分数
    
    for dialogue in result.dialogues:
        tone = dialogue.tone.lower()
        if tone in ["愤怒", "焦虑", "紧张", "angry", "anxious", "tense"]:
            score -= 20
        elif tone in ["轻松", "平静", "relaxed", "calm"]:
            score += 5
    
    score -= len(result.risks) * 10
    return max(0, min(100, score))


def generate_tags(result: AudioAnalysisResponse) -> List[str]:
    """生成标签"""
    tags = []
    
    for risk in result.risks:
        if "PUA" in risk or "pua" in risk.lower():
            tags.append("#PUA预警")
        if "预算" in risk or "budget" in risk.lower():
            tags.append("#预算")
        if "争议" in risk or "dispute" in risk.lower():
            tags.append("#争议")
    
    tones = [d.tone for d in result.dialogues]
    if any("愤怒" in t or "angry" in t.lower() for t in tones):
        tags.append("#急躁")
    if any("画饼" in t or "promise" in t.lower() for t in tones):
        tags.append("#画饼")
    
    return tags if tags else ["#正常"]


@app.post("/api/v1/audio/upload", response_model=APIResponse)
async def upload_audio_api(
    file: UploadFile = File(...),
    title: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """上传音频文件并开始分析（需要JWT认证）"""
    import asyncio
    from datetime import datetime
    
    t_enter = time.time()
    logger.info("========== [upload] 进入 handler ==========")
    logger.info(f"文件名: {file.filename} Content-Type: {file.content_type} Title: {title} User: {user_id[:8]}...")
    
    try:
        session_id = str(uuid.uuid4())
        logger.info(f"生成 session_id: {session_id}")
        
        if not title:
            formatter = datetime.now().strftime("%H:%M")
            title = f"录音 {formatter}"
        
        start_time = datetime.now()
        
        # 创建数据库Session记录
        db_session = Session(
            id=uuid.UUID(session_id),
            user_id=uuid.UUID(user_id),
            title=title,
            start_time=start_time,
            duration=0,
            status="analyzing",
            tags=[]
        )
        db.add(db_session)
        await db.commit()
        await db.refresh(db_session)
        t_after_db = time.time() - t_enter
        logger.info(f"[upload] 数据库Session已创建 session_id={session_id} 耗时={t_after_db:.2f}s")
        
        # 保留内存存储用于向后兼容（可选）
        task_data = {
            "session_id": session_id,
            "user_id": user_id,
            "title": title,
            "start_time": start_time.isoformat(),
            "end_time": None,
            "duration": 0,
            "tags": [],
            "status": "analyzing",
            "emotion_score": None,
            "speaker_count": None,
            "created_at": start_time.isoformat(),
            "updated_at": start_time.isoformat()
        }
        tasks_storage[session_id] = task_data
        logger.info(f"任务数据已存储: {session_id}")
        
        # 读取文件内容并保存到临时文件（必须在异步任务之前读取，因为 UploadFile 只能读取一次）
        # 注意：不限制文件大小，Gemini 支持大文件；Nginx 需配置 client_max_body_size 100M 以上
        t_before_read = time.time()
        logger.info("[upload] 开始读取文件内容（await file.read，大文件时此步骤较慢）...")
        file_content = await file.read()
        file_size = len(file_content)
        t_read_elapsed = time.time() - t_before_read
        logger.info(f"[upload] 文件读取完成 size={file_size} bytes ({file_size / 1024 / 1024:.2f} MB) 耗时={t_read_elapsed:.2f}s")
        
        file_filename = file.filename or "audio.m4a"
        file_ext = Path(file_filename).suffix.lower() if file_filename else '.m4a'
        
        # 创建临时文件保存文件内容
        import tempfile
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_ext)
        temp_file.write(file_content)
        temp_file.close()
        temp_file_path = temp_file.name
        logger.info(f"[upload] 临时文件已创建: {temp_file_path}")
        
        # 异步分析（传递临时文件路径和文件名，确保所有参数都正确传递）
        # 注意：不传递db会话，在异步任务中创建新的会话
        logger.info(f"创建异步分析任务: session_id={session_id}, file_path={temp_file_path}, filename={file_filename}")
        asyncio.create_task(analyze_audio_async(session_id, temp_file_path, file_filename, task_data, user_id))
        
        # 构建响应数据
        response_data = {
            "session_id": session_id,
            "user_id": user_id,
            "audio_id": session_id,
            "title": title,
            "status": "analyzing",
            "estimated_duration": 300,
            "created_at": start_time.isoformat()
        }
        
        api_response = APIResponse(
            code=200,
            message="上传成功",
            data=response_data,
            timestamp=datetime.now().isoformat()
        )
        
        t_total = time.time() - t_enter
        logger.info(f"[upload] ========== 准备返回响应 总耗时={t_total:.2f}s ==========")
        logger.info(f"[upload] 响应: code={api_response.code} session_id={session_id}")
        
        # 使用 JSONResponse 确保正确序列化
        return JSONResponse(
            content=api_response.dict(),
            status_code=200,
            headers={"Content-Type": "application/json"}
        )
    except Exception as e:
        logger.error(f"========== 上传音频失败 ==========")
        logger.error(f"错误类型: {type(e).__name__}")
        logger.error(f"错误信息: {str(e)}")
        logger.error(f"完整错误堆栈:")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


async def analyze_audio_async(session_id: str, temp_file_path: str, file_filename: str, task_data: dict, user_id: str):
    """异步分析音频文件（保存到数据库）"""
    from datetime import datetime
    from database.connection import AsyncSessionLocal
    
    # 创建新的数据库会话（因为原会话可能已关闭）
    async with AsyncSessionLocal() as db:
        try:
            logger.info(f"[分析-{session_id}] ========== 开始异步分析 ==========")
            logger.info(f"session_id: {session_id}")
            logger.info(f"user_id: {user_id}")
            logger.info(f"temp_file_path: {temp_file_path}")
            logger.info(f"file_filename: {file_filename}")
            logger.info(f"task_data keys: {list(task_data.keys()) if task_data else 'None'}")
            
            # 验证参数
            if not task_data:
                raise ValueError("task_data 参数不能为空")
            if not session_id:
                raise ValueError("session_id 参数不能为空")
            if not temp_file_path:
                raise ValueError("temp_file_path 参数不能为空")
            
            # 检查文件是否存在
            if not os.path.exists(temp_file_path):
                raise FileNotFoundError(f"临时文件不存在: {temp_file_path}")
            
            logger.info(f"[分析-{session_id}] step_async1: 分析任务开始，文件大小: {os.path.getsize(temp_file_path)} 字节")
            # 直接进入 Gemini 分析阶段（原音频不上传阿里云，仅本地存储）
            _uq = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
            _us = _uq.scalar_one_or_none()
            if _us:
                _us.analysis_stage = "gemini_analysis"
                await db.commit()
            
            # 原音频持久化到本地（秒级，供剪切与声纹使用；默认不上传 OSS）
            audio_url, audio_path = await asyncio.to_thread(
                persist_original_audio, session_id, temp_file_path, file_filename or "audio.m4a", user_id
            )
            result_query = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
            db_session_audio = result_query.scalar_one_or_none()
            if db_session_audio:
                db_session_audio.audio_url = audio_url
                db_session_audio.audio_path = audio_path
                await db.commit()
                logger.info(f"[分析-{session_id}] Session 已更新原音频: audio_url={bool(audio_url)}, audio_path={bool(audio_path)}")
            
            logger.info(f"[分析-{session_id}] step_async2: 本地存储完成，即将调用 Gemini")
            
            # 在 executor 中运行 Gemini 分析（避免阻塞事件循环），带 6 分钟超时
            logger.info(f"[分析-{session_id}] step_async3: 即将调用 analyze_audio_from_path（executor）")
            def _run_analysis():
                return asyncio.run(analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a", session_id=session_id))
            try:
                result, call1_result = await asyncio.wait_for(
                    asyncio.get_event_loop().run_in_executor(None, _run_analysis),
                    timeout=360.0  # 6 分钟超时，防止 Gemini 上传卡住导致永久 analyzing
                )
                logger.info(f"[分析-{session_id}] step_async4: analyze_audio_from_path 返回成功")
            except asyncio.TimeoutError:
                logger.error(f"[分析-{session_id}] step_async4: 6 分钟超时！Gemini 分析未在限时内完成")
                raise Exception("分析超时（6 分钟），可能因 Gemini 文件上传失败或代理不可达，请检查网络/代理配置")
            
            # 使用Call1结果或旧结果
            if call1_result:
                emotion_score = call1_result.mood_score
                stats = call1_result.stats
                summary = call1_result.summary
                transcript = [t.dict() for t in call1_result.transcript]
            else:
                emotion_score = calculate_emotion_score(result)
                stats = {"sigh": 0, "laugh": 0}
                summary = ""
                transcript = []
            
            tags = generate_tags(result)
            
            end_time = datetime.now()
            duration = int((end_time - datetime.fromisoformat(task_data["start_time"])).total_seconds())
            
            # 更新内存存储（向后兼容）
            task_data.update({
                "end_time": end_time.isoformat(),
                "duration": duration,
                "status": "archived",
                "emotion_score": emotion_score,
                "speaker_count": result.speaker_count,
                "tags": tags,
                "updated_at": end_time.isoformat()
            })
            
            # 更新数据库Session
            result_query = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
            db_session = result_query.scalar_one_or_none()
            if db_session:
                db_session.end_time = end_time
                db_session.duration = duration
                db_session.status = "archived"
                db_session.analysis_stage = None  # 完成时清除
                db_session.error_message = None  # 成功时清除旧失败原因
                db_session.emotion_score = emotion_score
                db_session.speaker_count = result.speaker_count
                db_session.tags = tags
                await db.commit()
                logger.info(f"数据库Session已更新: {session_id}")
            
            # 保存分析结果到数据库
            analysis_result = AnalysisResult(
                session_id=uuid.UUID(session_id),
                dialogues=[d.dict() for d in result.dialogues],
                risks=result.risks,
                summary=summary,
                mood_score=emotion_score,
                stats=stats,
                transcript=json.dumps(transcript, ensure_ascii=False) if transcript else None,
                call1_result=call1_result.dict() if call1_result else None
            )
            db.add(analysis_result)
            await db.commit()
            logger.info(f"分析结果已保存到数据库: {session_id}")
            
            # 更新进度：声纹匹配
            _vq = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
            _vs = _vq.scalar_one_or_none()
            if _vs:
                _vs.analysis_stage = "voiceprint"
                await db.commit()
            
            # 分析后流程：按说话人选代表片段 → 声纹识别 → 写 speaker_mapping
            speaker_mapping = {}
            has_audio = bool(audio_url or audio_path)
            logger.info(f"[声纹] session_id={session_id} transcript_len={len(transcript) if transcript else 0} has_audio={has_audio} audio_url={bool(audio_url)} audio_path={bool(audio_path)}")
            if not transcript:
                logger.info(f"[声纹] session_id={session_id} 无 transcript，跳过声纹匹配")
            elif not has_audio:
                logger.info(f"[声纹] session_id={session_id} 无原音频 URL/路径，跳过声纹匹配")
            if transcript and has_audio:
                try:
                    from utils.audio_storage import get_session_audio_local_path
                    def _ts_to_sec(ts):
                        if not ts:
                            return 0.0
                        try:
                            parts = str(ts).split(":")
                            if len(parts) == 2:
                                return int(parts[0]) * 60 + float(parts[1])
                        except Exception:
                            pass
                        return 0.0
                    # 为每个 speaker 取第一句的 (start_sec, end_sec)
                    first_segment = {}
                    for i, t in enumerate(transcript):
                        sp = t.get("speaker") or "未知"
                        if sp not in first_segment:
                            start_sec = _ts_to_sec(t.get("timestamp"))
                            if i + 1 < len(transcript):
                                end_sec = _ts_to_sec(transcript[i + 1].get("timestamp"))
                            else:
                                end_sec = float(duration) if duration else start_sec + 5.0
                            if end_sec <= start_sec:
                                end_sec = start_sec + 2.0
                            first_segment[sp] = (start_sec, end_sec)
                    local_path, is_temp = get_session_audio_local_path(audio_url, audio_path)
                    logger.info(f"[声纹] session_id={session_id} 本地音频 local_path={bool(local_path)} is_temp={is_temp} speakers={list(first_segment.keys())}")
                    if not local_path:
                        logger.warning(f"[声纹] session_id={session_id} 无法获取本地音频（下载或路径失败），跳过声纹匹配")
                    if local_path:
                        profile_result = await db.execute(
                            select(Profile.id, Profile.relationship_type).where(Profile.user_id == uuid.UUID(user_id))
                        )
                        _rows = profile_result.all()
                        profile_ids = [str(row[0]) for row in _rows]
                        self_profile_id = None
                        for row in _rows:
                            rel = row[1] if len(row) > 1 else None
                            if rel == "自己":
                                self_profile_id = str(row[0])
                                break
                        logger.info(f"[声纹] session_id={session_id} 当前用户档案数 profile_count={len(profile_ids)} self_profile_id={self_profile_id}")
                        if not profile_ids:
                            logger.warning(f"[声纹] session_id={session_id} 当前用户无档案，跳过声纹匹配")
                        # 占位：仅 1 个说话人且 1 个档案时直接映射
                        elif len(first_segment) == 1 and len(profile_ids) == 1:
                            only_sp = next(iter(first_segment.keys()))
                            speaker_mapping[only_sp] = profile_ids[0]
                            logger.info(f"[声纹] 占位单说话人单档案: {only_sp} -> {profile_ids[0]}")
                        else:
                            # 多人：利用 is_me 映射「自己」，其余不盲映射（避免新人误标为其他档案）
                            speaker_with_is_me = None
                            for t in transcript:
                                if t.get("is_me") is True:
                                    speaker_with_is_me = t.get("speaker")
                                    break
                            if self_profile_id and speaker_with_is_me:
                                speaker_mapping[speaker_with_is_me] = self_profile_id
                                logger.info(f"[声纹] 利用 is_me 映射自己: {speaker_with_is_me} -> {self_profile_id}")
                            # 非 is_me 的说话人（如新人）不再做盲映射
                        if is_temp and os.path.isfile(local_path):
                            try:
                                os.unlink(local_path)
                            except Exception:
                                pass
                    if speaker_mapping:
                        ar_result = await db.execute(select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id)))
                        ar = ar_result.scalar_one_or_none()
                        if ar:
                            ar.speaker_mapping = speaker_mapping
                            await db.commit()
                            logger.info(f"[声纹] session_id={session_id} speaker_mapping 已写入: {speaker_mapping}")
                        else:
                            logger.warning(f"[声纹] session_id={session_id} 未找到 AnalysisResult，无法写入 speaker_mapping")
                    else:
                        logger.info(f"[声纹] session_id={session_id} speaker_mapping 为空，未写入")
                except Exception as e:
                    logger.warning(f"[声纹] session_id={session_id} 分析后声纹匹配失败: {e}", exc_info=True)
            
            # 第二次 Gemini：总结「谁和谁对话」
            conversation_summary = None
            if transcript:
                try:
                    profile_names = {}
                    if speaker_mapping:
                        profile_ids_in_mapping = list(speaker_mapping.values())
                        if profile_ids_in_mapping:
                            profile_res = await db.execute(
                                select(Profile.id, Profile.name, Profile.relationship_type).where(
                                    Profile.user_id == uuid.UUID(user_id),
                                    Profile.id.in_([uuid.UUID(pid) for pid in profile_ids_in_mapping])
                                )
                            )
                            for row in profile_res.all():
                                name = row.name or "未知"
                                rel = getattr(row, "relationship_type", None) or "未知"
                                profile_names[str(row.id)] = f"{name}（{rel}）"
                    lines = []
                    for t in transcript:
                        sp = t.get("speaker") or "未知"
                        name = profile_names.get(speaker_mapping.get(sp, ""), sp)
                        text = (t.get("text") or "").strip()
                        lines.append(f"{name}: {text}")
                    display_text = "\n".join(lines)
                    prompt = f"""根据以下对话，总结这是谁和谁的对话（角色关系、对话主题、双方立场等）。对话格式为 说话人: 内容。请用一两段话概括，不要列点。

对话：
{display_text}

总结："""
                    model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
                    resp = model.generate_content(prompt)
                    if resp and resp.text:
                        conversation_summary = resp.text.strip()
                        ar_res = await db.execute(select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id)))
                        ar = ar_res.scalar_one_or_none()
                        if ar:
                            ar.conversation_summary = conversation_summary
                            await db.commit()
                            logger.info(f"conversation_summary 已写入: {session_id}")
                except Exception as e:
                    logger.warning(f"第二次 Gemini 总结失败: {e}", exc_info=True)
            
            # v0.6 记忆提取（B 钩子）：档案匹配完成后写入 Mem0
            if speaker_mapping and conversation_summary and profile_names:
                logger.info(f"[记忆] B 钩子触发: session_id={session_id} speaker_mapping={speaker_mapping} profile_names_keys={list(profile_names.keys())}")
                try:
                    from services.memory_service import build_memory_payload, add_memory
                    payload = build_memory_payload(
                        transcript, conversation_summary, speaker_mapping, profile_names
                    )
                    metadata = {
                        "session_id": session_id,
                        "profile_ids": list(speaker_mapping.values()),
                    }
                    logger.info(f"[记忆] B 钩子调用 add_memory: session_id={session_id} payload_len={len(payload)}")
                    # 同步 add_memory 在线程中执行，避免阻塞事件循环
                    ok = await asyncio.to_thread(
                        add_memory,
                        payload,
                        user_id,
                        metadata=metadata,
                        enable_graph=True,
                    )
                    logger.info(f"[记忆] B 钩子 add_memory 结果: session_id={session_id} success={ok}")
                except Exception as mem_err:
                    logger.warning(f"[记忆] B 钩子写入失败: session_id={session_id} error={mem_err}", exc_info=True)
            else:
                logger.info(f"[记忆] B 钩子跳过: session_id={session_id} speaker_mapping={bool(speaker_mapping)} conversation_summary={bool(conversation_summary)} profile_names={bool(profile_names)}")
            
            # 存储分析结果到内存（向后兼容）
            analysis_storage[session_id] = {
                "dialogues": [d.dict() for d in result.dialogues],
                "risks": result.risks,
                "call1": call1_result.dict() if call1_result else None,
                "mood_score": emotion_score,
                "stats": stats,
                "summary": summary,
                "transcript": transcript
            }
            
            logger.info(f"任务 {session_id} 分析完成")
            
            # 异步生成策略分析（不阻塞主流程）
            logger.info(f"开始异步生成策略分析: {session_id}")
            asyncio.create_task(generate_strategies_async(session_id, user_id))
            
        except Exception as e:
            logger.error(f"[分析-{session_id}] ❌ 分析音频失败: {type(e).__name__}: {str(e)}")
            logger.error(traceback.format_exc())
            
            # 更新内存存储
            err_msg = str(e)[:500]
            task_data["status"] = "failed"
            task_data["error_message"] = err_msg
            task_data["updated_at"] = datetime.now().isoformat()

            # 更新数据库状态
            try:
                result_query = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
                db_session = result_query.scalar_one_or_none()
                if db_session:
                    db_session.status = "failed"
                    db_session.analysis_stage = "failed"
                    db_session.error_message = err_msg
                    await db.commit()
                    logger.info(f"数据库Session状态已更新为 failed: {session_id}")
                else:
                    logger.warning(f"未找到数据库Session: {session_id}")
            except Exception as db_error:
                logger.error(f"更新数据库状态失败: {db_error}")
        finally:
            # 清理临时文件
            if temp_file_path and os.path.exists(temp_file_path):
                try:
                    os.unlink(temp_file_path)
                    logger.info(f"已删除临时文件: {temp_file_path}")
                except Exception as e:
                    logger.error(f"删除临时文件失败: {e}")


@app.get("/api/v1/tasks/sessions")
async def get_task_list(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    date: Optional[str] = None,
    status: Optional[str] = None,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取任务列表（需要JWT认证，仅返回当前用户的任务）"""
    from datetime import datetime
    
    t_start = time.time()
    logger.info(f"[任务列表] 进入 handler user_id={user_id[:8]}... page={page} page_size={page_size}")
    try:
        # 从数据库查询当前用户的任务
        t0 = time.time()
        query = select(Session).where(Session.user_id == uuid.UUID(user_id))
        
        if date:
            target_date = datetime.fromisoformat(date).date()
            query = query.where(
                func.date(Session.start_time) == target_date
            )
        
        if status:
            query = query.where(Session.status == status)
        
        query = query.order_by(Session.created_at.desc())
        
        # 首屏性能优化：不执行 count，只请求 page_size+1 条以判断 has_more
        query = query.offset((page - 1) * page_size).limit(page_size + 1)
        result = await db.execute(query)
        sessions = result.scalars().all()
        db_elapsed = time.time() - t0
        if db_elapsed > 2.0:
            logger.warning(f"[任务列表] Session 查询耗时 {db_elapsed:.2f}s count={len(sessions)}")
        has_more = len(sessions) > page_size
        if has_more:
            sessions = sessions[:page_size]
        
        session_ids = [str(s.id) for s in sessions]
        summary_map = {}
        cover_map = {}
        
        if session_ids:
            ar_result = await db.execute(select(AnalysisResult).where(AnalysisResult.session_id.in_([uuid.UUID(sid) for sid in session_ids])))
            for ar in ar_result.scalars().all():
                summary_map[str(ar.session_id)] = ar.summary
            sa_result = await db.execute(select(StrategyAnalysis).where(StrategyAnalysis.session_id.in_([uuid.UUID(sid) for sid in session_ids])))
            api_base = os.getenv("API_PUBLIC_URL", "http://47.79.254.213")
            api_base = api_base.rstrip("/")
            for sa in sa_result.scalars().all():
                sid = str(sa.session_id)
                vd = sa.visual_data
                if isinstance(vd, list) and len(vd) > 0:
                    first_v = vd[0] if isinstance(vd[0], dict) else getattr(vd[0], "__dict__", {})
                    img_url = first_v.get("image_url") if isinstance(first_v, dict) else getattr(first_v, "image_url", None)
                    if img_url:
                        # 统一走代理 API（需 JWT），避免 OSS 私有 URL 直接访问 403
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
                cover_image_url=cover_map.get(str(s.id))
            )
            for s in sessions
        ]
        
        total_elapsed = time.time() - t_start
        logger.info(f"[任务列表] 完成 total={total_elapsed:.2f}s sessions={len(task_items)}")
        return APIResponse(
            code=200,
            message="success",
            data={
                "sessions": [t.dict() for t in task_items],
                "pagination": {
                    "page": page,
                    "page_size": page_size,
                    "has_more": has_more
                }
            },
            timestamp=datetime.now().isoformat()
        )
    except Exception as e:
        logger.error(f"获取任务列表失败: {type(e).__name__}: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取列表失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}")
async def get_task_detail(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """获取任务详情（需要JWT认证，仅能访问自己的任务）"""
    from datetime import datetime
    
    try:
        # 从数据库查询任务，确保属于当前用户
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id)
            )
        )
        db_session = result.scalar_one_or_none()
        
        if not db_session:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        # 查询分析结果
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
            speaker_mapping = analysis_result.speaker_mapping if isinstance(analysis_result.speaker_mapping, dict) else None
            conversation_summary = getattr(analysis_result, "conversation_summary", None) or None
            name_to_display = {}  # 档案名/角色名 -> 展示格式，用于替换 Gemini 直接写出的角色名（如梁致远）
            speaker_names = None

            # 解析 transcript（来自 transcript 字段或 call1_result）
            transcript = []
            if getattr(analysis_result, "transcript", None):
                try:
                    transcript = json.loads(analysis_result.transcript) if isinstance(analysis_result.transcript, str) else (analysis_result.transcript or [])
                except Exception:
                    transcript = []
            if not transcript and getattr(analysis_result, "call1_result", None):
                call1 = analysis_result.call1_result
                if isinstance(call1, dict) and "transcript" in call1:
                    transcript = call1.get("transcript") or []

            # 优先使用 transcript + is_me 计算正确的 speaker_names（修复旧任务错误映射）
            self_profile_id = None
            self_display = None
            profile_rows = await db.execute(
                select(Profile.id, Profile.name, Profile.relationship_type).where(Profile.user_id == uuid.UUID(user_id))
            )
            for row in profile_rows.all():
                rel = getattr(row, "relationship_type", None) or (row[2] if len(row) > 2 else None)
                if rel == "自己":
                    self_profile_id = str(getattr(row, "id", row[0]))
                    name = getattr(row, "name", None) or (row[1] if len(row) > 1 else None) or "未知"
                    self_display = f"{name}（自己）"
                    if name and name.strip():
                        name_to_display[name.strip()] = self_display
                        if "志" in name or "致" in name:
                            alt = name.replace("志", "致") if "志" in name else name.replace("致", "志")
                            if alt != name:
                                name_to_display[alt.strip()] = self_display
                    break

            if transcript and self_profile_id and self_display:
                # 从 transcript 找 is_me=true 的 speaker，仅映射「自己」，其余保持 Speaker_X
                speaker_with_is_me = None
                for t in transcript:
                    if t.get("is_me") is True:
                        speaker_with_is_me = t.get("speaker")
                        break
                if speaker_with_is_me:
                    speaker_names = {speaker_with_is_me: self_display}
                    # 非 is_me 的说话人不映射，_speaker_to_display 会返回原 speaker_val（如 Speaker_0）
                    logger.info(f"[任务详情] session={session_id} 使用 transcript+is_me 计算 speaker_names: {speaker_names}，未映射者显示为 Speaker_X")
            elif speaker_mapping and not speaker_names:
                # 无 transcript/is_me 时回退到 speaker_mapping（兼容旧逻辑）
                profile_ids_in_mapping = list(speaker_mapping.values())
                if profile_ids_in_mapping:
                    try:
                        profile_res = await db.execute(
                            select(Profile.id, Profile.name, Profile.relationship_type).where(
                                Profile.user_id == uuid.UUID(user_id),
                                Profile.id.in_([uuid.UUID(pid) for pid in profile_ids_in_mapping])
                            )
                        )
                        id_to_display = {}
                        for row in profile_res.all():
                            name = row.name or "未知"
                            rel = getattr(row, "relationship_type", None) or "未知"
                            display = f"{name}（{rel}）"
                            id_to_display[str(row.id)] = display
                            if name and name.strip():
                                name_to_display[name.strip()] = display
                                if "志" in name or "致" in name:
                                    alt = name.replace("志", "致") if "志" in name else name.replace("致", "志")
                                    if alt != name:
                                        name_to_display[alt.strip()] = display
                        speaker_names = {sp: id_to_display.get(pid, sp) for sp, pid in speaker_mapping.items()}
                    except Exception:
                        speaker_names = None
            
            # 若已有 speaker_names，返回前在 summary / conversation_summary / dialogues 中把 Speaker_0/Speaker_1 替换为档案名
            def _replace_speaker_labels(text: Optional[str], names: dict) -> Optional[str]:
                if not text or not names:
                    return text
                for sp in sorted(names.keys(), key=len, reverse=True):
                    text = text.replace(sp, names[sp])
                # Call #1 约定 Speaker_1 为用户，Gemini 总结常写「用户」而非 Speaker_1，一并替换为档案名
                if "Speaker_1" in names:
                    text = text.replace("用户", names["Speaker_1"])
                # 兼容其他写法：说话人0/1、Speaker0/1（无下划线）
                alias_map = [("说话人0", "Speaker_0"), ("说话人1", "Speaker_1"), ("Speaker0", "Speaker_0"), ("Speaker1", "Speaker_1")]
                for alias, canonical in alias_map:
                    if canonical in names and alias in text:
                        text = text.replace(alias, names[canonical])
                return text

            def _replace_profile_names(text: Optional[str], name_map: dict) -> Optional[str]:
                """替换 Gemini 在总结中直接写出的档案名/角色名（如 梁致远）为 档案名（关系）"""
                if not text or not name_map:
                    return text
                for name in sorted(name_map.keys(), key=len, reverse=True):
                    # 仅替换作为独立词出现的档案名，避免误替换（如「梁致远说」中的梁致远）
                    text = text.replace(name, name_map[name])
                return text

            def _speaker_to_display(speaker_val: str, names: dict) -> str:
                """将说话人标签转为档案名展示"""
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
                # 额外替换：Gemini 可能在总结中直接写出角色名（如梁致远），需替换为 档案名（关系）
                summary = _replace_profile_names(summary, name_to_display)
                conversation_summary = _replace_profile_names(conversation_summary, name_to_display)
                # 每条 dialogue 的 speaker 字段也替换为档案名，便于前端直接展示
                if dialogues:
                    new_dialogues = []
                    for d in dialogues:
                        if isinstance(d, dict) and "speaker" in d:
                            d = dict(d)  # 深拷贝一层，避免改原始数据
                            d["speaker"] = _speaker_to_display(d.get("speaker", ""), speaker_names)
                        new_dialogues.append(d)
                    dialogues = new_dialogues
                logger.info(f"[任务详情] session={session_id} 已对 summary/conversation_summary/dialogues 做档案名替换 speaker_names={list(speaker_names.keys())}")
        
        detail = TaskDetailResponse(
            session_id=str(db_session.id),
            title=db_session.title or "",
            start_time=db_session.start_time.isoformat() if db_session.start_time else "",
            end_time=db_session.end_time.isoformat() if db_session.end_time else None,
            duration=db_session.duration or 0,
            tags=db_session.tags or [],
            status=db_session.status or "unknown",
            error_message=getattr(db_session, "error_message", None) or None,
            emotion_score=db_session.emotion_score,
            speaker_count=db_session.speaker_count,
            dialogues=dialogues,
            risks=risks,
            summary=summary,
            speaker_mapping=speaker_mapping,
            speaker_names=speaker_names,
            conversation_summary=conversation_summary,
            created_at=db_session.created_at.isoformat() if db_session.created_at else "",
            updated_at=db_session.updated_at.isoformat() if db_session.updated_at else ""
        )
        
        return APIResponse(
            code=200,
            message="success",
            data=detail.dict(),
            timestamp=datetime.now().isoformat()
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
    db: AsyncSession = Depends(get_db)
):
    """查询任务分析状态（需要JWT认证，仅能访问自己的任务）"""
    from datetime import datetime
    
    try:
        # 从数据库查询任务，确保属于当前用户
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id)
            )
        )
        db_session = result.scalar_one_or_none()
        
        if not db_session:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        status_value = db_session.status or "unknown"
        analysis_stage = getattr(db_session, "analysis_stage", None) or ""
        
        # 根据阶段估算进度与剩余时间
        if status_value == "archived":
            progress_val, eta = 1.0, 0
        elif status_value == "failed":
            progress_val, eta = 0.0, 0
        else:
            stage_map = {"gemini_analysis": (0.5, 45), "voiceprint": (0.9, 10)}
            progress_val, eta = stage_map.get(analysis_stage, (0.3, 60))
        
        payload = {
            "session_id": session_id,
            "status": status_value,
            "progress": progress_val,
            "estimated_time_remaining": eta,
            "analysis_stage": analysis_stage,
            "updated_at": db_session.updated_at.isoformat() if db_session.updated_at else ""
        }
        if status_value == "failed" and getattr(db_session, "error_message", None):
            payload["failure_reason"] = db_session.error_message
        return APIResponse(
            code=200,
            message="success",
            data=payload,
            timestamp=datetime.now().isoformat()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务状态失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取状态失败: {str(e)}")


async def generate_strategies_async(session_id: str, user_id: str):
    """异步生成策略分析（在音频分析完成后自动调用）"""
    from datetime import datetime
    from database.connection import AsyncSessionLocal
    
    # 创建新的数据库会话
    async with AsyncSessionLocal() as db:
        try:
            logger.info(f"========== 开始异步生成策略分析 ==========")
            logger.info(f"session_id: {session_id}, user_id: {user_id}")
            
            # 验证任务存在且属于当前用户
            result = await db.execute(
                select(Session).where(
                    Session.id == uuid.UUID(session_id),
                    Session.user_id == uuid.UUID(user_id)
                )
            )
            db_session = result.scalar_one_or_none()
            
            if not db_session:
                logger.error(f"任务不存在: {session_id}")
                return
            
            # 从数据库查询分析结果
            analysis_result_query = await db.execute(
                select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
            )
            analysis_result_db = analysis_result_query.scalar_one_or_none()
            
            if not analysis_result_db:
                logger.error(f"分析结果不存在: {session_id}")
                return
            
            # 获取transcript
            transcript = []
            if analysis_result_db.transcript:
                try:
                    transcript = json.loads(analysis_result_db.transcript) if isinstance(analysis_result_db.transcript, str) else analysis_result_db.transcript
                except:
                    transcript = []
            
            # 向后兼容：从内存存储获取（如果数据库中没有）
            analysis_result = analysis_storage.get(session_id, {})
            if not transcript and analysis_result:
                transcript = analysis_result.get("transcript", [])
            
            if not transcript:
                logger.error(f"对话转录数据不存在: {session_id}")
                return
            
            # 调用核心策略生成逻辑
            await _generate_strategies_core(session_id, user_id, transcript, db)
            
        except Exception as e:
            logger.error(f"异步生成策略分析失败: {e}")
            logger.error(traceback.format_exc())


_SKILL_ID_TO_NAME = {
    "workplace_jungle": "职场丛林",
    "family_relationship": "家庭关系",
    "education_communication": "教育沟通",
    "brainstorm": "头脑风暴",
    "emotion_recognition": "情绪识别",
}


def _build_legacy_skill_cards(visual_data: list, strategies: list, applied_skills: list) -> list:
    """从旧格式 visual_data + strategies 构造兼容的 skill_cards 结构"""
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
        "content": {"visual": v_dicts, "strategies": s_dicts}
    }]


async def _generate_strategies_core(session_id: str, user_id: str, transcript: list, db: AsyncSession):
    """策略生成核心逻辑（v0.4 技能化架构）"""
    from datetime import datetime
    import asyncio
    
    try:
        logger.info(f"========== 开始生成策略分析（v0.4 技能化架构） ==========")
        logger.info(f"session_id: {session_id}")
        
        # 2.1 场景识别（Router Agent）
        logger.info("[策略流程] 步骤2.1: 场景识别(Gemini classify_scene)...")
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
        scene_result = classify_scene(transcript, model)
        primary_scene = scene_result.get("primary_scene", "other")
        scenes = scene_result.get("scenes", [])
        logger.info(f"[策略流程] 步骤2.1: 完成 primary_scene={primary_scene}")
        for scene in scenes:
            logger.info(f"  - {scene.get('category')}: {scene.get('confidence', 0):.2f}")
        
        # 2.2 技能匹配（若此处报 PG type 114，可能是 skills 表 meta_data 列为 json）
        logger.info("[策略流程] 步骤2.2: 技能匹配(match_skills/查 skills 表)...")
        matched_skills = await match_skills(scene_result, db, transcript=transcript)
        logger.info(f"[策略流程] 步骤2.2: 完成 匹配到 {len(matched_skills)} 个技能")
        
        if not matched_skills:
            logger.warning("未匹配到任何技能，使用默认技能")
            # 使用 workplace_jungle 作为默认技能
            default_skill = await get_skill("workplace_jungle", db)
            if default_skill:
                matched_skills = [{
                    "skill_id": "workplace_jungle",
                    "name": default_skill["name"],
                    "category": default_skill["category"],
                    "priority": default_skill["priority"],
                    "confidence": 0.5
                }]
            else:
                raise Exception("未匹配到技能且默认技能不存在")
        
        for skill in matched_skills:
            logger.info(f"  ✅ 技能: {skill['skill_id']} (名称: {skill.get('name', 'N/A')}, priority={skill['priority']}, confidence={skill['confidence']:.2f})")
        
        # 2.2b v0.6 记忆检索：为技能注入相关记忆
        memory_context = ""
        try:
            logger.info(f"[记忆] 开始检索: session_id={session_id} user_id={user_id}")
            ar_query = await db.execute(
                select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
            )
            ar_row = ar_query.scalar_one_or_none()
            if ar_row:
                search_query = getattr(ar_row, "conversation_summary", None) or ar_row.summary or ""
                if not search_query and transcript:
                    search_query = " ".join((t.get("text", "") or "")[:100] for t in transcript[:5])
                logger.info(f"[记忆] 检索 query 来源: conversation_summary={bool(getattr(ar_row, 'conversation_summary', None))} summary={bool(ar_row.summary)} search_query_len={len(search_query)}")
                if search_query:
                    from services.memory_service import search_memory
                    mem_results = await asyncio.to_thread(
                        search_memory, search_query, user_id, limit=5
                    )
                    if mem_results:
                        memory_context = "\n".join(f"- {m}" for m in mem_results)
                        logger.info(f"[记忆] 检索成功注入技能: session_id={session_id} 命中={len(mem_results)} 条 context_len={len(memory_context)}")
                    else:
                        logger.info(f"[记忆] 检索无命中: session_id={session_id}")
                else:
                    logger.info(f"[记忆] 检索跳过: search_query 为空 session_id={session_id}")
            else:
                logger.info(f"[记忆] 检索跳过: 无 AnalysisResult session_id={session_id}")
        except Exception as mem_err:
            logger.warning(f"[记忆] 检索失败: session_id={session_id} error={mem_err}", exc_info=True)
        context = {
            "session_id": session_id,
            "user_id": user_id,
            "memory_context": memory_context or "",
        }
        
        # 2.3 技能执行：transcript + 技能 prompt -> Gemini -> 策略与视觉描述
        logger.info("[策略流程] 步骤2.3: 技能执行(transcript+技能prompt->Gemini)...")
        skill_results = []
        
        # 并行执行所有技能
        execution_tasks = []
        for matched_skill in matched_skills:
            skill_id = matched_skill["skill_id"]
            try:
                # 获取完整技能信息（包含 prompt_template）
                skill = await get_skill(skill_id, db)
                if not skill:
                    logger.warning(f"技能不存在: {skill_id}")
                    continue
                
                # 添加匹配信息到技能数据
                skill["priority"] = matched_skill["priority"]
                skill["confidence"] = matched_skill["confidence"]
                
                # 创建执行任务
                task = execute_skill(skill, transcript, context, model)
                execution_tasks.append((skill_id, task))
            except Exception as e:
                logger.error(f"准备执行技能失败: {skill_id}, 错误: {e}")
                skill_results.append({
                    "skill_id": skill_id,
                    "result": None,
                    "execution_time_ms": 0,
                    "success": False,
                    "error_message": str(e),
                    "priority": matched_skill.get("priority", 0),
                    "confidence": matched_skill.get("confidence", 0.5)
                })
        
        # 执行所有任务
        for skill_id, task in execution_tasks:
            try:
                result = await task
                skill_results.append(result)
            except Exception as e:
                logger.error(f"执行技能失败: {skill_id}, 错误: {e}")
                skill_results.append({
                    "skill_id": skill_id,
                    "result": None,
                    "execution_time_ms": 0,
                    "success": False,
                    "error_message": str(e),
                    "priority": 0,
                    "confidence": 0.5
                })
        
        # 记录技能执行到数据库
        for skill_result in skill_results:
            try:
                skill_execution = SkillExecution(
                    session_id=uuid.UUID(session_id),
                    skill_id=skill_result["skill_id"],
                    scene_category=primary_scene,
                    confidence_score=skill_result.get("confidence", 0.5),
                    execution_time_ms=skill_result.get("execution_time_ms", 0),
                    success=skill_result.get("success", False),
                    error_message=skill_result.get("error_message")
                )
                db.add(skill_execution)
            except Exception as e:
                logger.error(f"记录技能执行失败: {skill_result['skill_id']}, 错误: {e}")
        
        await db.commit()
        
        # 4. 构建 skill_cards（每个技能一张卡片，不再用 compose_results 合并）
        logger.info("[策略流程] 步骤2.3a: 构建 skill_cards...")
        skill_cards = []
        all_visuals_for_compat = []  # 用于兼容 visual_data
        all_strategies_for_compat = []  # 用于兼容 strategies
        global_image_index = 0
        reference_images = await _get_profile_reference_images(session_id, user_id, db)
        
        for skill_result in skill_results:
            skill_id = skill_result.get("skill_id", "unknown")
            skill_name = skill_result.get("name", skill_id)
            if not skill_result.get("success"):
                continue
            # 情绪技能
            if skill_result.get("emotion_insight") is not None:
                emotion_insight = skill_result["emotion_insight"]
                skill_cards.append({
                    "skill_id": skill_id,
                    "skill_name": skill_name,
                    "content_type": "emotion",
                    "content": {
                        "sigh_count": emotion_insight.get("sigh_count", 0),
                        "haha_count": emotion_insight.get("haha_count", 0),
                        "mood_state": emotion_insight.get("mood_state", "平常心"),
                        "mood_emoji": emotion_insight.get("mood_emoji", "😐"),
                        "char_count": emotion_insight.get("char_count", 0),
                    }
                })
                logger.info(f"  ✅ 情绪卡: {skill_id} mood={emotion_insight.get('mood_state')} sigh={emotion_insight.get('sigh_count')} haha={emotion_insight.get('haha_count')}")
                continue
            # 策略技能
            result = skill_result.get("result")
            if result and hasattr(result, "visual") and hasattr(result, "strategies"):
                # 为策略技能的 visual 生成图片
                updated_visual_list = []
                for v in result.visual:
                    try:
                        image_result = generate_image_from_prompt(
                            v.image_prompt,
                            user_id,
                            session_id,
                            global_image_index,
                            reference_images=reference_images if reference_images else None,
                        )
                        if image_result:
                            if image_result.startswith('http://') or image_result.startswith('https://'):
                                updated_visual = v.model_copy(update={"image_url": image_result})
                            else:
                                updated_visual = v.model_copy(update={"image_base64": image_result})
                            updated_visual_list.append(updated_visual)
                        else:
                            updated_visual_list.append(v)
                    except Exception as e:
                        logger.error(f"生成图片失败 {skill_id} idx={global_image_index}: {e}")
                        updated_visual_list.append(v)
                    global_image_index += 1
                card_content = {
                    "visual": [v.dict() for v in updated_visual_list],
                    "strategies": [s.dict() for s in result.strategies]
                }
                skill_cards.append({
                    "skill_id": skill_id,
                    "skill_name": skill_name,
                    "content_type": "strategy",
                    "content": card_content
                })
                all_visuals_for_compat.extend(updated_visual_list)
                all_strategies_for_compat.extend(result.strategies)
                logger.info(f"  ✅ 策略卡: {skill_id} visual={len(updated_visual_list)} strategies={len(result.strategies)}")
        
        # 兼容：从 skill_cards 反推 call2_result（首张策略卡或合并）
        if all_visuals_for_compat or all_strategies_for_compat:
            all_visuals_for_compat.sort(key=lambda x: x.transcript_index)
            if len(all_visuals_for_compat) > 5:
                all_visuals_for_compat = all_visuals_for_compat[:5]
            call2_result = Call2Response(visual=all_visuals_for_compat, strategies=all_strategies_for_compat)
        else:
            call2_result = Call2Response(visual=[], strategies=[])
        logger.info(f"[策略流程] 步骤2.3a: 完成 skill_cards={len(skill_cards)} 兼容visual={len(call2_result.visual)} 兼容strategies={len(call2_result.strategies)}")
        
        # v0.6 记忆补充（C 钩子）：策略文本写入 Mem0
        if call2_result.strategies:
            logger.info(f"[记忆] C 钩子触发: session_id={session_id} 策略数={len(call2_result.strategies)}")
            try:
                from services.memory_service import add_memory
                strategy_text = "\n\n".join(
                    f"[{s.title}] {s.content}" for s in call2_result.strategies
                )
                ar_q = await db.execute(
                    select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
                )
                ar = ar_q.scalar_one_or_none()
                profile_ids = []
                if ar and isinstance(getattr(ar, "speaker_mapping", None), dict):
                    profile_ids = list(ar.speaker_mapping.values())
                skill_ids = [s["skill_id"] for s in skill_results if s.get("success")]
                metadata = {"session_id": session_id, "profile_ids": profile_ids}
                if skill_ids:
                    metadata["skill_ids"] = skill_ids
                logger.info(f"[记忆] C 钩子调用 add_memory: session_id={session_id} strategy_text_len={len(strategy_text)} metadata={metadata}")
                ok = await asyncio.to_thread(
                    add_memory, strategy_text, user_id, metadata=metadata, enable_graph=True
                )
                logger.info(f"[记忆] C 钩子 add_memory 结果: session_id={session_id} success={ok}")
            except Exception as mem_err:
                logger.warning(f"[记忆] C 钩子写入失败: session_id={session_id} error={mem_err}", exc_info=True)
        else:
            logger.info(f"[记忆] C 钩子跳过: session_id={session_id} strategies 为空")
        
        # 6. 保存策略分析到数据库（若此处或 commit 后报 PG type 114，说明 strategy_analysis 表列为 json 未改为 jsonb）
        logger.info("[策略流程] 步骤2.4: 写入策略分析到数据库(StrategyAnalysis)...")
        
        # 构建 applied_skills 列表
        applied_skills = [
            {
                "skill_id": skill_result["skill_id"],
                "priority": skill_result.get("priority", 0),
                "confidence": skill_result.get("confidence", 0.5)
            }
            for skill_result in skill_results
            if skill_result.get("success", False)
        ]
        
        # 获取主要场景的置信度（存储为 float，不是 JSONB）
        primary_scene_confidence = None
        for scene in scenes:
            if scene.get("category") == primary_scene:
                primary_scene_confidence = scene.get("confidence", 0.5)
                break
        if primary_scene_confidence is None:
            primary_scene_confidence = 0.5
        
        strategy_analysis = StrategyAnalysis(
            session_id=uuid.UUID(session_id),
            visual_data=[v.dict() for v in call2_result.visual],
            strategies=[s.dict() for s in call2_result.strategies],
            applied_skills=applied_skills,
            scene_category=primary_scene,
            scene_confidence=primary_scene_confidence,
            skill_cards=skill_cards
        )
        
        # 如果已存在则更新，否则创建
        existing_query = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        existing = existing_query.scalar_one_or_none()
        if existing:
            existing.visual_data = [v.dict() for v in call2_result.visual]
            existing.strategies = [s.dict() for s in call2_result.strategies]
            existing.applied_skills = applied_skills
            existing.scene_category = primary_scene
            existing.scene_confidence = primary_scene_confidence
            existing.skill_cards = skill_cards
            await db.commit()
            logger.info(f"[策略流程] 步骤2.4: 已更新到数据库: {session_id}")
        else:
            db.add(strategy_analysis)
            await db.commit()
            logger.info(f"[策略流程] 步骤2.4: 已保存到数据库: {session_id}")
        
        # 存储策略结果到内存（向后兼容）
        if session_id not in analysis_storage:
            analysis_storage[session_id] = {}
        if "call2" not in analysis_storage[session_id]:
            analysis_storage[session_id]["call2"] = {}
        analysis_storage[session_id]["call2"] = call2_result.dict()
        
        logger.info(f"策略分析生成成功（v0.4 技能化架构）")
        logger.info(f"  - 场景类别: {primary_scene} (置信度: {primary_scene_confidence:.2f})")
        logger.info(f"  - 应用技能: {len(applied_skills)} 个")
        for skill in applied_skills:
            skill_id = skill['skill_id']
            # 从技能结果中获取名称，如果没有则从数据库查询
            skill_name = skill.get('name', 'N/A')
            if skill_name == 'N/A':
                try:
                    skill_info = await get_skill(skill_id, db)
                    skill_name = skill_info.get('name', skill_id) if skill_info else skill_id
                except:
                    skill_name = skill_id
            logger.info(f"    ✅ 技能: {skill_id} (名称: {skill_name}, priority={skill['priority']}, confidence={skill['confidence']:.2f})")
        logger.info(f"  - 关键时刻数量: {len(call2_result.visual)}")
        logger.info(f"  - 策略数量: {len(call2_result.strategies)}")
        
        return call2_result
        
    except Exception as e:
        logger.error(f"生成策略失败: {e}")
        logger.error(traceback.format_exc())
        raise


@app.post("/api/v1/tasks/sessions/{session_id}/classify-scene")
async def classify_scene_endpoint(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """场景识别接口（仅进行场景识别，不生成策略）"""
    from datetime import datetime
    
    try:
        # 验证任务存在且属于当前用户
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id)
            )
        )
        db_session = result.scalar_one_or_none()
        
        if not db_session:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        # 从数据库查询分析结果
        analysis_result_query = await db.execute(
            select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
        )
        analysis_result_db = analysis_result_query.scalar_one_or_none()
        
        if not analysis_result_db:
            raise HTTPException(status_code=400, detail="分析结果不存在，请先完成音频分析")
        
        # 获取transcript
        transcript = []
        if analysis_result_db.transcript:
            try:
                transcript = json.loads(analysis_result_db.transcript) if isinstance(analysis_result_db.transcript, str) else analysis_result_db.transcript
            except:
                transcript = []
        
        if not transcript:
            raise HTTPException(status_code=400, detail="对话转录数据不存在，请先完成音频分析")
        
        # 场景识别
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
        scene_result = classify_scene(transcript, model)
        
        # 技能匹配（传入 transcript 用于参与者关键词补充）
        matched_skills = await match_skills(scene_result, db, transcript=transcript)
        
        return APIResponse(
            code=200,
            message="success",
            data={
                "scenes": scene_result.get("scenes", []),
                "primary_scene": scene_result.get("primary_scene", "other"),
                "matched_skills": [
                    {
                        "skill_id": skill["skill_id"],
                        "name": skill["name"],
                        "priority": skill["priority"]
                    }
                    for skill in matched_skills
                ]
            },
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"场景识别失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"场景识别失败: {str(e)}")


@app.post("/api/v1/tasks/sessions/{session_id}/strategies")
async def generate_strategies(
    session_id: str,
    force_regenerate: bool = Query(False, description="强制重新生成（用于更新为最新风格如宫崎骏）"),
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """生成策略分析（Call #2）- 情商教练（v0.4 技能化架构，需要JWT认证，仅能访问自己的任务）。force_regenerate=true 时删除旧数据并重新生成。"""
    from datetime import datetime
    
    try:
        logger.info(f"[策略流程] session_id={session_id} 开始")
        # 验证任务存在且属于当前用户
        result = await db.execute(
            select(Session).where(
                Session.id == uuid.UUID(session_id),
                Session.user_id == uuid.UUID(user_id)
            )
        )
        db_session = result.scalar_one_or_none()
        
        if not db_session:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        # 步骤0：优先从数据库读取已生成的策略分析（若此处报 PG type 114，说明 strategy_analysis 表列为 json 未改为 jsonb）
        logger.info(f"[策略流程] 步骤0: 读取已有策略分析(StrategyAnalysis)...")
        strategy_query = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        existing_strategy = strategy_query.scalar_one_or_none()
        logger.info(f"[策略流程] 步骤0: 完成 existing={existing_strategy is not None} force_regenerate={force_regenerate}")
        
        if force_regenerate and existing_strategy:
            from sqlalchemy import delete
            await db.execute(delete(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id)))
            await db.commit()
            logger.info(f"[策略流程] 已删除旧策略分析，将重新生成: {session_id}")
            existing_strategy = None
        
        if existing_strategy:
            logger.info(f"从数据库读取已生成的策略分析: {session_id}")
            # 构建返回数据（兼容 visual_data/strategies 为空或仅 emotion 卡）
            visual_list = []
            for idx, v in enumerate(existing_strategy.visual_data or []):
                vdict = v if isinstance(v, dict) else (v.__dict__ if hasattr(v, '__dict__') else {})
                has_url = bool(vdict.get("image_url"))
                has_b64 = bool(vdict.get("image_base64"))
                b64_len = len(vdict.get("image_base64") or "")
                logger.info(f"[策略-图片] session_id={session_id} visual[{idx}] image_url={has_url} image_base64={bool(has_b64)} b64_len={b64_len}")
                visual_list.append(VisualData(**vdict))
            
            strategies_list = []
            for s in (existing_strategy.strategies or []):
                sdict = s if isinstance(s, dict) else (s.__dict__ if hasattr(s, '__dict__') else {})
                strategies_list.append(StrategyItem(**sdict))
            
            call2_result = Call2Response(
                visual=visual_list,
                strategies=strategies_list
            )
            
            # 添加技能信息
            result_dict = call2_result.dict()
            applied_skills = existing_strategy.applied_skills or []
            scene_category = existing_strategy.scene_category
            scene_confidence = existing_strategy.scene_confidence
            # 优先使用 skill_cards，无则从 visual_data+strategies 构造兼容结构
            skill_cards_raw = getattr(existing_strategy, "skill_cards", None) or []
            if skill_cards_raw:
                result_dict["skill_cards"] = skill_cards_raw
            else:
                result_dict["skill_cards"] = _build_legacy_skill_cards(
                    existing_strategy.visual_data or [],
                    existing_strategy.strategies or [],
                    applied_skills
                )
            
            logger.info(f"技能信息: applied_skills={applied_skills}, scene_category={scene_category}, scene_confidence={scene_confidence}")
            # 日志：返回给前端的 visual 中每个的 image_url / image_base64 情况
            for idx, v in enumerate(result_dict.get("visual", [])):
                vd = v if isinstance(v, dict) else (getattr(v, "__dict__", {}) or {})
                url_present = bool(vd.get("image_url"))
                b64_present = bool(vd.get("image_base64"))
                logger.info(f"[策略返回] session_id={session_id} visual[{idx}] 返回image_url={url_present} image_base64={b64_present}")
            
            result_dict["applied_skills"] = applied_skills
            result_dict["scene_category"] = scene_category
            result_dict["scene_confidence"] = scene_confidence
            
            return APIResponse(
                code=200,
                message="success",
                data=result_dict,
                timestamp=datetime.now().isoformat()
            )
        
        # 如果数据库中没有，则生成新的策略分析
        logger.info(f"[策略流程] 数据库中没有策略分析，开始生成: {session_id}")
        
        # 步骤1：从数据库查询分析结果取 transcript（若此处报 PG type 114，说明 analysis_results 表列为 json 未改为 jsonb）
        logger.info(f"[策略流程] 步骤1: 读取分析结果(AnalysisResult/transcript)...")
        analysis_result_query = await db.execute(
            select(AnalysisResult).where(AnalysisResult.session_id == uuid.UUID(session_id))
        )
        analysis_result_db = analysis_result_query.scalar_one_or_none()
        logger.info(f"[策略流程] 步骤1: 完成 analysis_result_db={analysis_result_db is not None}")
        
        if not analysis_result_db:
            raise HTTPException(status_code=400, detail="分析结果不存在，请先完成音频分析")
        
        # 获取transcript
        transcript = []
        if analysis_result_db.transcript:
            try:
                transcript = json.loads(analysis_result_db.transcript) if isinstance(analysis_result_db.transcript, str) else analysis_result_db.transcript
            except:
                transcript = []
        
        # 向后兼容：从内存存储获取（如果数据库中没有）
        analysis_result = analysis_storage.get(session_id, {})
        if not transcript and analysis_result:
            transcript = analysis_result.get("transcript", [])
        
        if not transcript:
            raise HTTPException(status_code=400, detail="对话转录数据不存在，请先完成音频分析")
        
        # 步骤2：核心生成（步骤2.1 场景识别 -> 2.2 技能匹配 -> 2.3 transcript+技能 prompt -> Gemini）
        logger.info(f"[策略流程] 步骤2: 调用 _generate_strategies_core(场景识别->技能匹配->Gemini策略)...")
        call2_result = await _generate_strategies_core(session_id, user_id, transcript, db)
        logger.info(f"[策略流程] 步骤2: _generate_strategies_core 返回成功")
        
        # 步骤3：从数据库读取刚写入的策略以取技能信息（若此处报 PG type 114，说明 strategy_analysis 表列为 json 未改为 jsonb）
        logger.info(f"[策略流程] 步骤3: 读取刚写入的策略分析(技能信息)...")
        strategy_query_after = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        strategy_after = strategy_query_after.scalar_one_or_none()
        
        # 添加技能信息到返回数据
        result_dict = call2_result.dict()
        if strategy_after:
            applied_skills = strategy_after.applied_skills or []
            scene_category = strategy_after.scene_category
            scene_confidence = strategy_after.scene_confidence
            # 优先使用 skill_cards
            skill_cards_raw = getattr(strategy_after, "skill_cards", None) or []
            if skill_cards_raw:
                result_dict["skill_cards"] = skill_cards_raw
            else:
                result_dict["skill_cards"] = _build_legacy_skill_cards(
                    strategy_after.visual_data or [],
                    strategy_after.strategies or [],
                    applied_skills
                )
            
            logger.info(f"技能信息: applied_skills={applied_skills}, scene_category={scene_category}, scene_confidence={scene_confidence}")
            
            result_dict["applied_skills"] = applied_skills
            result_dict["scene_category"] = scene_category
            result_dict["scene_confidence"] = scene_confidence
        else:
            logger.warning(f"未找到策略分析数据，无法返回技能信息: {session_id}")
            result_dict["applied_skills"] = []
            result_dict["scene_category"] = None
            result_dict["scene_confidence"] = None
            result_dict["skill_cards"] = []
        
        return APIResponse(
            code=200,
            message="success",
            data=result_dict,
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"生成策略失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"生成策略失败: {str(e)}")


@app.get("/api/v1/tasks/emotion-trend")
async def get_emotion_trend(
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    limit: int = Query(30, ge=1, le=100)
):
    """
    获取心情趋势：从各 session 的 skill_cards 中提取 content_type=emotion 的数据，按时间排序。
    """
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
            timestamp=datetime.now().isoformat()
        )
    except Exception as e:
        logger.error(f"获取心情趋势失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"获取心情趋势失败: {str(e)}")


@app.get("/api/v1/images/{session_id}/{image_index}")
async def get_image(
    session_id: str,
    image_index: int,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    获取图片（通过后端 API 访问，支持私有 OSS bucket，需要JWT认证）
    
    注意：由于 OSS bucket 设置为私有，不能直接通过 OSS URL 访问图片。
    必须通过此 API 接口访问，后端会从 OSS 获取图片并返回。
    仅能访问属于当前用户的图片。
    
    Args:
        session_id: 会话 ID
        image_index: 图片索引
        
    Returns:
        图片数据（PNG 格式）
    """
    try:
        # 档案照片：session_id 为 profile_{uuid}，无需查 Session 表
        # 策略图片：session_id 为任务 UUID，需验证归属
        if session_id.startswith("profile_"):
            # 档案照片路径 images/{user_id}/profile_xxx/0.png，仅校验 user_id 归属
            pass
        else:
            # 策略图片：验证任务属于当前用户
            result = await db.execute(
                select(Session).where(
                    Session.id == uuid.UUID(session_id),
                    Session.user_id == uuid.UUID(user_id)
                )
            )
            db_session = result.scalar_one_or_none()
            if not db_session:
                raise HTTPException(status_code=404, detail="任务不存在")
        
        # 如果 OSS 未启用，返回错误
        if not USE_OSS or oss_bucket is None:
            logger.warning("OSS 未启用，无法提供图片访问")
            raise HTTPException(status_code=503, detail="Image service unavailable")
        
        # 构建 OSS 文件路径: images/{user_id}/{session_id}/{image_index}.png
        oss_key = f"images/{user_id}/{session_id}/{image_index}.png"
        
        logger.info(f"获取图片: {oss_key}")
        
        try:
            # 从 OSS 获取图片
            start_time = time.time()
            image_object = oss_bucket.get_object(oss_key)
            image_data = image_object.read()
            fetch_time = time.time() - start_time
            
            logger.info(f"✅ 图片获取成功，大小: {len(image_data)} 字节，耗时: {fetch_time:.2f} 秒")
            
            media_type = "image/png"
            if len(image_data) >= 2 and image_data[0:2] == b"\xff\xd8":
                media_type = "image/jpeg"
            elif len(image_data) >= 4 and image_data[0:4] == b"\x89PNG":
                media_type = "image/png"
            
            return Response(
                content=image_data,
                media_type=media_type,
                headers={
                    "Cache-Control": "public, max-age=3600",  # 缓存 1 小时
                    "Content-Disposition": f'inline; filename="image_{image_index}.png"'
                }
            )
            
        except Exception as e:
            error_msg = str(e)
            if "NoSuchKey" in error_msg or "404" in error_msg:
                logger.warning(f"图片不存在: {oss_key}")
                raise HTTPException(status_code=404, detail="Image not found")
            else:
                logger.error(f"❌ 从 OSS 获取图片失败: {e}")
                logger.error(traceback.format_exc())
                raise HTTPException(status_code=500, detail="Failed to fetch image")
                
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ 获取图片时出错: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Internal server error")


def cleanup_old_images(days: int = 7):
    """
    清理过期的图片文件
    
    Args:
        days: 保留天数，默认 7 天
    """
    if not USE_OSS or oss_bucket is None:
        logger.warning("OSS 未启用，无法清理图片")
        return
    
    try:
        from datetime import datetime, timedelta
        cutoff_date = datetime.now() - timedelta(days=days)
        
        logger.info(f"开始清理 {days} 天前的图片文件...")
        
        # 列出所有图片文件
        prefix = "images/"
        deleted_count = 0
        error_count = 0
        
        for obj in oss2.ObjectIterator(oss_bucket, prefix=prefix):
            # 检查文件修改时间
            if obj.last_modified < cutoff_date:
                try:
                    oss_bucket.delete_object(obj.key)
                    deleted_count += 1
                    logger.debug(f"删除文件: {obj.key}")
                except Exception as e:
                    error_count += 1
                    logger.error(f"删除文件失败 {obj.key}: {e}")
        
        logger.info(f"✅ 清理完成: 删除 {deleted_count} 个文件，失败 {error_count} 个")
        
    except Exception as e:
        logger.error(f"❌ 清理图片文件失败: {e}")
        logger.error(traceback.format_exc())


@app.get("/api/v1/admin/cleanup-images")
async def cleanup_images_endpoint(days: int = Query(7, ge=1, le=30)):
    """
    清理过期图片的管理接口
    
    Args:
        days: 保留天数，默认 7 天
    """
    try:
        cleanup_old_images(days)
        return {"message": f"清理完成，保留最近 {days} 天的图片", "status": "success"}
    except Exception as e:
        logger.error(f"清理图片失败: {e}")
        raise HTTPException(status_code=500, detail=f"清理失败: {str(e)}")


@app.get("/test-gemini")
async def test_gemini():
    """测试 Gemini 3 Flash API 连接"""
    try:
        print("测试 Gemini 3 Flash API 连接...")
        model_name = GEMINI_FLASH_MODEL
        print(f"使用模型: {model_name}")
        model = genai.GenerativeModel(model_name)
        response = model.generate_content("请回复'连接成功'")
        return {
            "status": "success",
            "message": "Gemini 3 Flash API 连接正常",
            "model": model_name,
            "response": response.text
        }
    except Exception as e:
        error_msg = str(e)
        print(f"Gemini 3 Flash 连接失败: {error_msg}")
        return {
            "status": "error",
            "message": "Gemini 3 Flash API 连接失败",
            "error": error_msg
        }


if __name__ == "__main__":
    import uvicorn
    # 与 Nginx proxy_pass 一致：服务器上 Nginx 代理 80 -> 8000，此处必须监听 8000
    port = int(os.getenv("UVICORN_PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)

