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
from io import BytesIO
from typing import List, Optional, Any, Tuple
from pathlib import Path
from datetime import datetime

import google.generativeai as genai
from google import genai as genai_new  # 新的 SDK 用于图片生成
from google.genai import types as genai_types
from fastapi import FastAPI, UploadFile, File, HTTPException, Query, Depends
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

# 初始化 FastAPI 应用
app = FastAPI(title="音频分析服务", description="通过 Gemini API 分析音频文件")

# 注册认证路由
from api.auth import router as auth_router
app.include_router(auth_router)

# 导入数据库相关
from database.connection import get_db, init_db, close_db
from database.models import User, Session, AnalysisResult, StrategyAnalysis
from auth.jwt_handler import get_current_user_id, get_current_user
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

# 配置 Gemini API
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PROXY_URL = os.getenv("PROXY_URL", "http://47.79.254.213/secret-channel")
USE_PROXY = os.getenv("USE_PROXY", "true").lower() == "true"

if not GEMINI_API_KEY:
    raise ValueError("请在 .env 文件中设置 GEMINI_API_KEY")

# 配置 Gemini 客户端，使用反向代理服务器
logger.info(f"API Key: {GEMINI_API_KEY[:10]}... (已隐藏)")
if USE_PROXY and PROXY_URL:
    logger.info(f"反向代理模式: 启用，代理服务器: {PROXY_URL}")
    
    # 对于反向代理，需要修改 API 的 base URL
    # google-generativeai SDK 使用 googleapiclient 和 httplib2
    try:
        from urllib.parse import urlparse, urljoin
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

# Call #2 数据模型（策略分析）
class StrategyItem(BaseModel):
    """策略项数据模型"""
    id: str  # 策略ID
    label: str  # 策略标签
    emoji: str  # 表情符号
    title: str  # 策略标题
    content: str  # 策略内容（Markdown格式）

class VisualData(BaseModel):
    """视觉数据模型"""
    transcript_index: int  # 关联的 transcript 索引
    speaker: str  # 说话人标识
    image_prompt: str  # 火柴人图片描述词（详细版）
    emotion: str  # 说话人情绪
    subtext: str  # 潜台词
    context: str  # 当时的情景或心理状态
    my_inner: str  # 我的内心OS
    other_inner: str  # 对方的内心OS
    image_url: Optional[str] = None  # 图片 URL（优先使用）
    image_base64: Optional[str] = None  # Base64 编码的图片数据（向后兼容，OSS 失败时使用）

class Call2Response(BaseModel):
    """Call #2 策略分析响应"""
    visual: List[VisualData]  # 视觉数据数组（关键时刻）
    strategies: List[StrategyItem]  # 策略列表


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
    print(f"等待文件处理，当前状态: {file.state}")
    
    while file.state.name == "PROCESSING":
        elapsed = time.time() - start_time
        if elapsed > max_wait_time:
            raise Exception(f"文件处理超时（超过 {max_wait_time} 秒），当前状态: {file.state}")
        
        time.sleep(2)
        try:
            file = genai.get_file(file.name)
            print(f"文件状态: {file.state} (已等待 {int(elapsed)} 秒)")
        except Exception as e:
            print(f"获取文件状态时出错: {e}")
            time.sleep(2)
            continue
    
    if file.state.name != "ACTIVE":
        raise Exception(f"文件处理失败，状态: {file.state}")
    
    return file


def upload_image_to_oss(image_bytes: bytes, user_id: str, session_id: str, image_index: int) -> Optional[str]:
    """
    上传图片到阿里云 OSS
    
    Args:
        image_bytes: 图片的字节数据
        user_id: 用户 ID
        session_id: 会话 ID
        image_index: 图片索引
        
    Returns:
        OSS URL，如果失败返回 None
    """
    if not USE_OSS or oss_bucket is None:
        logger.warning("OSS 未启用或未初始化，无法上传图片")
        return None
    
    try:
        # 构建 OSS 文件路径: images/{user_id}/{session_id}/{image_index}.png
        oss_key = f"images/{user_id}/{session_id}/{image_index}.png"
        
        logger.info(f"上传图片到 OSS: {oss_key}")
        logger.info(f"图片大小: {len(image_bytes)} 字节")
        
        # 上传图片到 OSS
        start_time = time.time()
        oss_bucket.put_object(oss_key, image_bytes, headers={'Content-Type': 'image/png'})
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


def generate_image_from_prompt(image_prompt: str, user_id: str, session_id: str, image_index: int, max_retries: int = 3) -> Optional[str]:
    """
    使用 Gemini Nano Banana 生成图片并上传到 OSS
    
    Args:
        image_prompt: 图片生成提示词
        user_id: 用户 ID（用于 OSS 文件路径）
        session_id: 会话 ID（用于 OSS 文件路径）
        image_index: 图片索引（用于 OSS 文件路径）
        max_retries: 最大重试次数（默认 3 次）
        
    Returns:
        图片 URL（如果 OSS 启用）或 Base64 编码的图片数据（如果 OSS 未启用或失败），如果失败返回 None
    """
    from google.genai.errors import ClientError
    
    client = genai_new.Client(api_key=GEMINI_API_KEY)
    
    # 配置图片生成参数
    config = genai_types.GenerateContentConfig(
        image_config=genai_types.ImageConfig(
            aspect_ratio="4:3"  # 1184x864，接近 1024x768
        )
    )
    
    for attempt in range(max_retries):
        try:
            if attempt > 0:
                logger.info(f"========== 重试生成图片 (第 {attempt + 1}/{max_retries} 次) ==========")
            else:
                logger.info(f"========== 开始生成图片 ==========")
            
            logger.info(f"提示词长度: {len(image_prompt)} 字符")
            logger.debug(f"提示词内容: {image_prompt[:200]}...")
            logger.info(f"调用模型: gemini-2.5-flash-image")
            logger.info(f"宽高比: 4:3 (1184x864)")
            
            start_time = time.time()
            response = client.models.generate_content(
                model="gemini-2.5-flash-image",
                contents=[image_prompt],
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


def parse_gemini_response(response_text: str) -> dict:
    """
    解析 Gemini 返回的文本，提取 JSON 数据
    
    Args:
        response_text: Gemini 返回的文本
        
    Returns:
        解析后的字典数据
    """
    # 尝试提取 JSON 部分（可能包含在 markdown 代码块中）
    text = response_text.strip()
    
    # 如果包含 ```json 或 ``` 标记，提取其中的内容
    if "```json" in text:
        start = text.find("```json") + 7
        end = text.find("```", start)
        if end != -1:
            text = text[start:end].strip()
    elif "```" in text:
        start = text.find("```") + 3
        end = text.find("```", start)
        if end != -1:
            text = text[start:end].strip()
    
    # 解析 JSON
    try:
        data = json.loads(text)
        return data
    except json.JSONDecodeError as e:
        # 如果解析失败，尝试修复常见的 JSON 问题
        print(f"JSON 解析错误: {e}")
        print(f"原始文本: {text}")
        raise HTTPException(status_code=500, detail=f"无法解析 Gemini 返回的 JSON: {str(e)}")


async def analyze_audio_from_path(temp_file_path: str, file_filename: str) -> Tuple[AudioAnalysisResponse, Optional[Call1Response]]:
    """
    从文件路径分析音频文件（内部函数）
    
    Args:
        temp_file_path: 临时文件路径
        file_filename: 文件名
        
    Returns:
        元组：(AudioAnalysisResponse, Optional[Call1Response])
        - AudioAnalysisResponse: 兼容旧版本的分析结果
        - Call1Response: 新的Call1格式数据（如果解析成功）
    """
    uploaded_file = None
    
    try:
        logger.info(f"========== 文件上传处理开始 ==========")
        logger.info(f"文件已保存到临时路径: {temp_file_path}")
        
        # 上传文件到 Gemini（添加超时和重试机制）
        file_size = os.path.getsize(temp_file_path)
        file_size_mb = file_size / 1024 / 1024
        logger.info(f"========== 开始上传文件到 Gemini ==========")
        logger.info(f"文件名: {file_filename}")
        logger.info(f"文件大小: {file_size} 字节 ({file_size_mb:.2f} MB)")
        logger.info(f"文件路径: {temp_file_path}")
        
        max_retries = 3
        retry_count = 0
        uploaded_file = None
        
        while retry_count < max_retries:
            try:
                logger.info(f"尝试上传（第 {retry_count + 1}/{max_retries} 次）...")
                logger.debug(f"调用 genai.upload_file()")
                logger.debug(f"参数: path={temp_file_path}, display_name={file_filename}")
                
                start_upload = time.time()
                uploaded_file = genai.upload_file(
                    path=temp_file_path,
                    display_name=file_filename
                )
                upload_time = time.time() - start_upload
                
                logger.info(f"✅ 文件上传成功！")
                logger.info(f"上传的文件名: {uploaded_file.name}")
                logger.info(f"文件状态: {uploaded_file.state}")
                logger.info(f"上传耗时: {upload_time:.2f} 秒")
                break
            except Exception as e:
                retry_count += 1
                error_msg = str(e)
                error_type = type(e).__name__
                logger.error(f"❌ 上传失败（第 {retry_count}/{max_retries} 次）")
                logger.error(f"错误类型: {error_type}")
                logger.error(f"错误信息: {error_msg}")
                logger.error(f"完整错误堆栈:")
                logger.error(traceback.format_exc())
                
                if retry_count >= max_retries:
                    logger.error(f"已达到最大重试次数，放弃上传")
                    raise Exception(f"上传文件失败（已重试 {max_retries} 次）: {error_msg}")
                
                logger.info(f"等待 5 秒后重试...")
                time.sleep(5)
        
        # 等待文件处理完成（最多等待 10 分钟）
        logger.info(f"========== 等待文件处理完成 ==========")
        logger.info(f"当前文件状态: {uploaded_file.state}")
        uploaded_file = wait_for_file_active(uploaded_file, max_wait_time=600)
        logger.info(f"✅ 文件处理完成，状态: ACTIVE")
        
        # 配置模型和提示词
        # 使用 Gemini 3 Flash 模型（根据官方文档：https://ai.google.dev/gemini-api/docs/gemini-3）
        # gemini-3-flash-preview: 免费层有配额，速度快，适合音频分析
        model_name = 'gemini-3-flash-preview'
        logger.info(f"========== 配置模型 ==========")
        logger.info(f"使用模型: {model_name}")
        model = genai.GenerativeModel(model_name)
        logger.info(f"模型初始化完成")
        
        # 使用新的提示词（Call #1 - Observer）
        prompt = """角色: 你是一个专业的语音分析与行为观察专家。

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
        
        # 调用模型进行分析（添加重试机制）
        logger.info(f"========== 开始调用 Gemini 模型分析音频 ==========")
        logger.info(f"模型: {model_name}")
        logger.info(f"提示词长度: {len(prompt)} 字符")
        max_retries = 3
        retry_count = 0
        response = None
        
        while retry_count < max_retries:
            try:
                logger.info(f"调用模型（第 {retry_count + 1}/{max_retries} 次）...")
                logger.debug(f"调用 model.generate_content()")
                start_generate = time.time()
                response = model.generate_content([
                    uploaded_file,
                    prompt
                ])
                generate_time = time.time() - start_generate
                logger.info(f"✅ 模型调用成功，耗时: {generate_time:.2f} 秒")
                break
            except Exception as e:
                retry_count += 1
                error_msg = str(e)
                error_type = type(e).__name__
                logger.error(f"❌ 调用模型失败（第 {retry_count}/{max_retries} 次）")
                logger.error(f"错误类型: {error_type}")
                logger.error(f"错误信息: {error_msg}")
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
        logger.error(f"========== 处理过程中发生错误 ==========")
        logger.error(f"错误类型: {error_type}")
        logger.error(f"错误信息: {error_msg}")
        logger.error(f"完整错误堆栈:")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"音频分析失败: {error_msg}")
    
    finally:
        # 删除 Gemini 上的文件
        if uploaded_file:
            try:
                genai.delete_file(uploaded_file.name)
                logger.info(f"已删除 Gemini 文件: {uploaded_file.name}")
            except Exception as e:
                logger.error(f"删除 Gemini 文件失败: {e}")


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
    emotion_score: Optional[int] = None
    speaker_count: Optional[int] = None
    dialogues: List[dict] = []
    risks: List[str] = []
    summary: Optional[str] = None  # 新增：对话总结
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
    
    logger.info("========== 收到音频上传请求 ==========")
    logger.info(f"文件名: {file.filename}")
    logger.info(f"Content-Type: {file.content_type}")
    logger.info(f"Title: {title}")
    logger.info(f"User ID: {user_id}")
    
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
        logger.info(f"数据库Session已创建: {session_id}")
        
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
        logger.info("开始读取文件内容...")
        file_content = await file.read()
        file_size = len(file_content)
        logger.info(f"文件内容读取完成，大小: {file_size} 字节 ({file_size / 1024 / 1024:.2f} MB)")
        
        file_filename = file.filename or "audio.m4a"
        file_ext = Path(file_filename).suffix.lower() if file_filename else '.m4a'
        
        # 创建临时文件保存文件内容
        import tempfile
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_ext)
        temp_file.write(file_content)
        temp_file.close()
        temp_file_path = temp_file.name
        logger.info(f"临时文件已创建: {temp_file_path}")
        logger.info(f"文件大小: {file_size} 字节 ({file_size / 1024 / 1024:.2f} MB)")
        
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
        
        logger.info("========== 准备返回响应 ==========")
        logger.info(f"响应码: {api_response.code}")
        logger.info(f"响应消息: {api_response.message}")
        logger.info(f"响应数据: {response_data}")
        logger.info(f"响应对象: {api_response}")
        logger.info(f"响应字典: {api_response.dict()}")
        
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
            logger.info(f"========== 开始异步分析音频 ==========")
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
            
            # 记录文件大小（不限制）
            file_size = os.path.getsize(temp_file_path)
            logger.info(f"文件大小: {file_size} 字节 ({file_size / 1024 / 1024:.2f} MB)")
            
            # 直接使用临时文件路径调用 analyze_audio_from_path
            result, call1_result = await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")
            
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
            logger.error(f"========== 分析音频失败 ==========")
            logger.error(f"session_id: {session_id}")
            logger.error(f"错误类型: {type(e).__name__}")
            logger.error(f"错误信息: {str(e)}")
            logger.error(traceback.format_exc())
            
            # 更新内存存储
            task_data["status"] = "failed"
            task_data["updated_at"] = datetime.now().isoformat()
            
            # 更新数据库状态
            try:
                result_query = await db.execute(select(Session).where(Session.id == uuid.UUID(session_id)))
                db_session = result_query.scalar_one_or_none()
                if db_session:
                    db_session.status = "failed"
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
    
    try:
        # 从数据库查询当前用户的任务
        query = select(Session).where(Session.user_id == uuid.UUID(user_id))
        
        if date:
            target_date = datetime.fromisoformat(date).date()
            query = query.where(
                func.date(Session.start_time) == target_date
            )
        
        if status:
            query = query.where(Session.status == status)
        
        query = query.order_by(Session.created_at.desc())
        
        # 获取总数
        count_result = await db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar() or 0
        
        # 分页查询
        query = query.offset((page - 1) * page_size).limit(page_size)
        result = await db.execute(query)
        sessions = result.scalars().all()
        
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
                speaker_count=s.speaker_count
            )
            for s in sessions
        ]
        
        return APIResponse(
            code=200,
            message="success",
            data={
                "sessions": [t.dict() for t in task_items],
                "pagination": {
                    "page": page,
                    "page_size": page_size,
                    "total": total,
                    "total_pages": (total + page_size - 1) // page_size
                }
            },
            timestamp=datetime.now().isoformat()
        )
    except Exception as e:
        logger.error(f"获取任务列表失败: {e}")
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
        
        if analysis_result:
            dialogues = analysis_result.dialogues if isinstance(analysis_result.dialogues, list) else []
            risks = analysis_result.risks or []
            summary = analysis_result.summary
        
        detail = TaskDetailResponse(
            session_id=str(db_session.id),
            title=db_session.title or "",
            start_time=db_session.start_time.isoformat() if db_session.start_time else "",
            end_time=db_session.end_time.isoformat() if db_session.end_time else None,
            duration=db_session.duration or 0,
            tags=db_session.tags or [],
            status=db_session.status or "unknown",
            emotion_score=db_session.emotion_score,
            speaker_count=db_session.speaker_count,
            dialogues=dialogues,
            risks=risks,
            summary=summary,
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
        
        return APIResponse(
            code=200,
            message="success",
            data={
                "session_id": session_id,
                "status": status_value,
                "progress": 1.0 if status_value == "archived" else 0.5,
                "estimated_time_remaining": 0 if status_value == "archived" else 30,
                "updated_at": db_session.updated_at.isoformat() if db_session.updated_at else ""
            },
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


async def _generate_strategies_core(session_id: str, user_id: str, transcript: list, db: AsyncSession):
    """策略生成核心逻辑（供异步函数和接口共用）"""
    from datetime import datetime
    
    try:
        # 构建提示词（使用需求文档中的提示词B）
        prompt = """角色: 你是一位精通博弈论、职场心理学与视觉修辞的深度沟通专家。

任务: 基于 Call #1 提供的对话转录音本，深入拆解双方的权力动态，并提供具备实战价值的应对策略与视觉化方案。

核心指令:
1. **博弈剖析**: 洞察对话文本背后的「权力位阶」与「隐性诉求」。
2. **自主策略研判**: **请勿使用固定分类**。请根据具体场景（如：需求加塞、情感勒索、沟通僵局），自主研判 3 种最具破局可能性的应对路径。每种策略需给出独特的 `label`（如：借力打力、柔性边界、认知对齐）。
3. **视觉建模**: 识别对话中的关键时刻（如情绪转折、冲突爆发、重要决策等），为每个关键时刻设计详细的火柴人绘图描述词。
   - **关键时刻识别**: 从对话转录中识别 2-5 个关键时刻，这些时刻应该能代表对话的核心冲突、情绪变化或重要转折点。
   - **构图规则**: 米色背景，极简火柴人线稿，左侧为用户，右侧为对方。
   - **详细要求**: 每个 `image_prompt` 必须包含：
     * 说话人位置和身份标注（明确标注左侧是用户，右侧是对方）
     * 说话人情绪表现（通过肢体语言、表情、姿态展现，如：耸肩、对峙、闪躲、前倾、后仰等）
     * 潜台词暗示（通过细微动作体现，如：眼神闪躲、手指敲击、身体转向等）
     * 当时的情景或心理状态描述（描述对话发生的具体情境和双方的心理状态）
   - **心理 OS**: 分别提炼出双方在此刻「想说但没说出口」的内心暗示语 (my_inner, other_inner)。

参数定义:
- **strategies**: 数组，每个策略包含 `id` (策略ID), `label` (风格标签), `emoji`, `title` (策略标题), `content` (Markdown 格式的详细建议与话术)。
- **visual**: 数组，包含 2-5 个关键时刻的视觉数据。每个元素包含：
  * `transcript_index`: 关联的 transcript 数组索引（从 0 开始）
  * `speaker`: 说话人标识（如 "Speaker_0" 或 "Speaker_1"）
  * `image_prompt`: 详细的火柴人绘图描述词（必须包含说话人标注、情绪表现、潜台词暗示、情景描述）
  * `emotion`: 说话人情绪（如：紧张、防御、愤怒、轻松等）
  * `subtext`: 潜台词（说话人真正想表达但没说出口的意思）
  * `context`: 当时的情景或心理状态（描述对话发生的具体情境）
  * `my_inner`: 我的内心OS（用户想说但没说出口的话）
  * `other_inner`: 对方的内心OS（对方想说但没说出口的话）

要求: 必须以纯 JSON 形式返回，确保结构能直接驱动前端渲染。

返回格式:
{{
  "visual": [
    {{
      "transcript_index": 3,
      "speaker": "Speaker_1",
      "image_prompt": "米色背景，极简火柴人线稿。左侧为用户（Speaker_1），标注'我'，身体微微后倾，双手交叉胸前，表情略显紧张，眼神看向右侧但不敢直视，手指在胸前轻敲，显示出内心的不安和防御。右侧为对方（Speaker_0），标注'对方'，身体前倾，右手指向左侧，表情严肃，显示出强势和施压的姿态。整体场景：办公室环境，双方隔着办公桌对峙，氛围紧张。",
      "emotion": "紧张、防御",
      "subtext": "感到被冒犯但试图保持礼貌",
      "context": "对方提出不合理要求，用户内心抗拒但表面配合，处于被动防御状态",
      "my_inner": "感到被冒犯但保持礼貌",
      "other_inner": "试探对方的弹性"
    }},
    {{
      "transcript_index": 7,
      "speaker": "Speaker_0",
      "image_prompt": "...",
      "emotion": "...",
      "subtext": "...",
      "context": "...",
      "my_inner": "...",
      "other_inner": "..."
    }}
  ],
  "strategies": [
    {{
      "id": "s1",
      "label": "策略标签",
      "emoji": "⚔️",
      "title": "策略标题",
      "content": "### 建议话术\\n1. **心理逻辑**: ...\\n2. **推荐话术**: '...'"
    }}
  ]
}}

对话转录:
{{transcript_json}}
"""
        
        transcript_json = json.dumps(transcript, ensure_ascii=False, indent=2)
        prompt = prompt.format(transcript_json=transcript_json)
        
        # 调用Gemini模型
        model_name = 'gemini-3-flash-preview'
        model = genai.GenerativeModel(model_name)
        
        logger.info(f"========== 开始生成策略分析 ==========")
        logger.info(f"session_id: {session_id}")
        logger.info(f"模型: {model_name}")
        
        response = model.generate_content(prompt)
        
        logger.info(f"Gemini 响应长度: {len(response.text)} 字符")
        logger.debug(f"Gemini 响应内容: {response.text[:1000]}...")  # 记录前1000字符
        
        try:
            analysis_data = parse_gemini_response(response.text)
        except Exception as e:
            logger.error(f"解析 Gemini 响应失败: {e}")
            logger.error(f"响应内容: {response.text}")
            raise Exception(f"解析策略分析结果失败: {str(e)}")
        
        # 验证解析结果
        if not isinstance(analysis_data, dict):
            logger.error(f"解析结果不是字典类型: {type(analysis_data)}, 内容: {analysis_data}")
            raise Exception("策略分析结果格式错误")
        
        if "visual" not in analysis_data:
            logger.error(f"缺少 'visual' 字段，可用字段: {list(analysis_data.keys())}")
            logger.error(f"完整响应: {json.dumps(analysis_data, ensure_ascii=False, indent=2)}")
            raise Exception("策略分析结果缺少 'visual' 字段")
        
        if "strategies" not in analysis_data:
            logger.error(f"缺少 'strategies' 字段，可用字段: {list(analysis_data.keys())}")
            raise Exception("策略分析结果缺少 'strategies' 字段")
        
        # 处理 visual 数据（支持数组和单个对象两种格式）
        visual_raw = analysis_data.get("visual")
        
        # 向后兼容：如果返回的是单个对象，转换为数组
        if isinstance(visual_raw, dict):
            logger.warning("收到单个 visual 对象，转换为数组格式以保持兼容")
            visual_raw = [visual_raw]
        elif not isinstance(visual_raw, list):
            logger.error(f"visual 字段格式错误，期望数组或对象，实际类型: {type(visual_raw)}")
            raise Exception("visual 字段必须是数组或对象")
        
        # 验证 visual 数组不为空
        if len(visual_raw) == 0:
            logger.warning("visual 数组为空，创建默认 visual")
            # 创建默认 visual（使用第一个 transcript 项）
            if transcript:
                first_item = transcript[0]
                visual_raw = [{
                    "transcript_index": 0,
                    "speaker": first_item.get("speaker", "Speaker_0"),
                    "image_prompt": "米色背景，极简火柴人线稿。左侧为用户，右侧为对方。",
                    "emotion": "未知",
                    "subtext": "",
                    "context": "对话开始",
                    "my_inner": "",
                    "other_inner": ""
                }]
            else:
                raise Exception("visual 数组为空且无法创建默认值")
        
        # 验证关键时刻数量（2-5 个）
        if len(visual_raw) > 5:
            logger.warning(f"关键时刻数量过多 ({len(visual_raw)} 个)，只保留前 5 个")
            visual_raw = visual_raw[:5]
        elif len(visual_raw) < 2:
            logger.warning(f"关键时刻数量较少 ({len(visual_raw)} 个)，建议至少 2 个")
        
        # 构建 VisualData 列表
        visual_list = []
        transcript_length = len(transcript)
        
        try:
            for idx, v in enumerate(visual_raw):
                # 验证 transcript_index
                transcript_index = v.get("transcript_index", idx)
                if transcript_index < 0 or transcript_index >= transcript_length:
                    logger.warning(f"transcript_index {transcript_index} 超出范围 (0-{transcript_length-1})，使用索引 {idx}")
                    transcript_index = min(idx, transcript_length - 1) if transcript_length > 0 else 0
                
                # 获取对应的 transcript 项以获取 speaker
                speaker = v.get("speaker", "")
                if not speaker and transcript_length > 0:
                    speaker = transcript[transcript_index].get("speaker", "Speaker_0")
                
                visual_data = VisualData(
                    transcript_index=transcript_index,
                    speaker=speaker,
                    image_prompt=v.get("image_prompt", ""),
                    emotion=v.get("emotion", ""),
                    subtext=v.get("subtext", ""),
                    context=v.get("context", ""),
                    my_inner=v.get("my_inner", ""),
                    other_inner=v.get("other_inner", "")
                )
                visual_list.append(visual_data)
        except Exception as e:
            logger.error(f"构建 VisualData 列表失败: {e}")
            logger.error(f"visual 数据: {visual_raw}")
            logger.error(traceback.format_exc())
            raise Exception(f"构建视觉数据失败: {str(e)}")
        
        # 为每个关键时刻生成图片
        logger.info(f"========== 开始为 {len(visual_list)} 个关键时刻生成图片 ==========")
        updated_visual_list = []
        for idx, visual_data in enumerate(visual_list):
            try:
                logger.info(f"生成图片 {idx+1}/{len(visual_list)}: transcript_index={visual_data.transcript_index}, speaker={visual_data.speaker}")
                image_result = generate_image_from_prompt(visual_data.image_prompt, user_id, session_id, idx)
                if image_result:
                    # 判断返回的是 URL 还是 Base64
                    if image_result.startswith('http://') or image_result.startswith('https://'):
                        # 是 URL，更新 image_url 字段
                        updated_visual = visual_data.model_copy(update={"image_url": image_result})
                        logger.info(f"✅ 图片 {idx+1} 生成成功，URL: {image_result}")
                    else:
                        # 是 Base64，更新 image_base64 字段（向后兼容）
                        updated_visual = visual_data.model_copy(update={"image_base64": image_result})
                        logger.info(f"✅ 图片 {idx+1} 生成成功，Base64 大小: {len(image_result)} 字符")
                    updated_visual_list.append(updated_visual)
                else:
                    # 即使生成失败，也保留 visual_data
                    updated_visual_list.append(visual_data)
                    logger.warning(f"⚠️ 图片 {idx+1} 生成失败，保留 visual_data")
            except Exception as e:
                logger.error(f"❌ 生成图片 {idx+1} 时出错: {e}")
                logger.error(traceback.format_exc())
                # 即使出错，也保留 visual_data
                updated_visual_list.append(visual_data)
        
        visual_list = updated_visual_list
        logger.info(f"========== 图片生成完成 ==========")
        
        strategies_list = []
        try:
            for s in analysis_data.get("strategies", []):
                strategies_list.append(StrategyItem(
                    id=s.get("id", ""),
                    label=s.get("label", ""),
                    emoji=s.get("emoji", ""),
                    title=s.get("title", ""),
                    content=s.get("content", "")
                ))
        except Exception as e:
            logger.error(f"构建策略列表失败: {e}")
            logger.error(f"strategies 数据: {analysis_data.get('strategies')}")
            raise Exception(f"构建策略列表失败: {str(e)}")
        
        call2_result = Call2Response(
            visual=visual_list,
            strategies=strategies_list
        )
        
        # 保存策略分析到数据库
        strategy_analysis = StrategyAnalysis(
            session_id=uuid.UUID(session_id),
            visual_data=[v.dict() for v in visual_list],
            strategies=[s.dict() for s in strategies_list]
        )
        # 如果已存在则更新，否则创建
        existing_query = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        existing = existing_query.scalar_one_or_none()
        if existing:
            existing.visual_data = [v.dict() for v in visual_list]
            existing.strategies = [s.dict() for s in strategies_list]
            await db.commit()
            logger.info(f"策略分析已更新到数据库: {session_id}")
        else:
            db.add(strategy_analysis)
            await db.commit()
            logger.info(f"策略分析已保存到数据库: {session_id}")
        
        # 存储策略结果到内存（向后兼容）
        if session_id not in analysis_storage:
            analysis_storage[session_id] = {}
        if "call2" not in analysis_storage[session_id]:
            analysis_storage[session_id]["call2"] = {}
        analysis_storage[session_id]["call2"] = call2_result.dict()
        
        logger.info(f"策略分析生成成功")
        logger.info(f"  - 关键时刻数量: {len(visual_list)}")
        logger.info(f"  - 策略数量: {len(strategies_list)}")
        for idx, v in enumerate(visual_list):
            # 优先检查 image_url，如果没有则检查 image_base64
            has_image = "✅" if (v.image_url or v.image_base64) else "❌"
            image_type = "URL" if v.image_url else ("Base64" if v.image_base64 else "None")
            logger.info(f"  - 关键时刻 {idx+1}: transcript_index={v.transcript_index}, speaker={v.speaker}, emotion={v.emotion}, 图片: {has_image} ({image_type})")
        
        return call2_result
        
    except Exception as e:
        logger.error(f"生成策略失败: {e}")
        logger.error(traceback.format_exc())
        raise


@app.post("/api/v1/tasks/sessions/{session_id}/strategies")
async def generate_strategies(
    session_id: str,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """生成策略分析（Call #2）- 情商教练（需要JWT认证，仅能访问自己的任务）"""
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
        
        # 优先从数据库读取已生成的策略分析
        strategy_query = await db.execute(
            select(StrategyAnalysis).where(StrategyAnalysis.session_id == uuid.UUID(session_id))
        )
        existing_strategy = strategy_query.scalar_one_or_none()
        
        if existing_strategy and existing_strategy.visual_data and existing_strategy.strategies:
            logger.info(f"从数据库读取已生成的策略分析: {session_id}")
            # 构建返回数据
            visual_list = []
            for v in existing_strategy.visual_data:
                visual_list.append(VisualData(**v))
            
            strategies_list = []
            for s in existing_strategy.strategies:
                strategies_list.append(StrategyItem(**s))
            
            call2_result = Call2Response(
                visual=visual_list,
                strategies=strategies_list
            )
            
            return APIResponse(
                code=200,
                message="success",
                data=call2_result.dict(),
                timestamp=datetime.now().isoformat()
            )
        
        # 如果数据库中没有，则生成新的策略分析
        logger.info(f"数据库中没有策略分析，开始生成: {session_id}")
        
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
        
        # 向后兼容：从内存存储获取（如果数据库中没有）
        analysis_result = analysis_storage.get(session_id, {})
        if not transcript and analysis_result:
            transcript = analysis_result.get("transcript", [])
        
        if not transcript:
            raise HTTPException(status_code=400, detail="对话转录数据不存在，请先完成音频分析")
        
        # 调用核心策略生成逻辑
        call2_result = await _generate_strategies_core(session_id, user_id, transcript, db)
        
        return APIResponse(
            code=200,
            message="success",
            data=call2_result.dict(),
            timestamp=datetime.now().isoformat()
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"生成策略失败: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail=f"生成策略失败: {str(e)}")


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
        # 验证任务属于当前用户
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
            
            # 返回图片数据，设置缓存头
            return Response(
                content=image_data,
                media_type="image/png",
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
        # 使用 Gemini 3 Flash（根据官方文档，免费层有配额）
        model_name = 'gemini-3-flash-preview'
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


@app.on_event("startup")
async def startup_event():
    """应用启动时初始化数据库"""
    try:
        logger.info("正在初始化数据库...")
        await init_db()
        logger.info("✅ 数据库初始化完成")
    except Exception as e:
        logger.error(f"❌ 数据库初始化失败: {e}")
        logger.error(traceback.format_exc())
        # 不阻止应用启动，允许在没有数据库的情况下运行（向后兼容）


@app.on_event("shutdown")
async def shutdown_event():
    """应用关闭时清理数据库连接"""
    try:
        await close_db()
        logger.info("✅ 数据库连接已关闭")
    except Exception as e:
        logger.error(f"关闭数据库连接时出错: {e}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)

