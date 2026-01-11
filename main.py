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
from io import BytesIO
from typing import List, Optional, Any
from pathlib import Path
from datetime import datetime

import google.generativeai as genai
from fastapi import FastAPI, UploadFile, File, HTTPException, Query
from pydantic import BaseModel
from dotenv import load_dotenv

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


# 定义返回数据模型
class DialogueItem(BaseModel):
    """单个对话项的数据模型"""
    speaker: str  # 说话人标识（如：说话人1、说话人A等）
    content: str  # 说话内容
    tone: str  # 说话语气（如：平静、愤怒、轻松、焦虑等）

class AudioAnalysisResponse(BaseModel):
    """音频分析结果的数据模型"""
    speaker_count: int  # 说话人数
    dialogues: List[DialogueItem]  # 所有对话列表，按时间顺序
    risks: List[str]  # 风险点列表


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


async def analyze_audio_from_path(temp_file_path: str, file_filename: str) -> AudioAnalysisResponse:
    """
    从文件路径分析音频文件（内部函数）
    
    Args:
        temp_file_path: 临时文件路径
        file_filename: 文件名
        
    Returns:
        结构化的音频分析结果
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
        
        prompt = """请分析这段音频，识别所有说话人及其对话内容。

要求：
1. 识别说话人数量。
2. 按时间顺序列出所有对话，每个对话包含：
   - 说话人标识（如：说话人1、说话人A、说话人B等）
   - 说话的具体内容（完整原话）
   - 说话的语气（如：平静、愤怒、轻松、焦虑、兴奋、严肃等）
3. 识别关键风险点。

请务必以纯 JSON 格式返回，不要包含 Markdown 标记。

返回格式必须严格遵循以下结构：
{
  "speaker_count": 数字,
  "dialogues": [
    {
      "speaker": "说话人1",
      "content": "说话的具体内容",
      "tone": "说话语气"
    },
    {
      "speaker": "说话人2",
      "content": "说话的具体内容",
      "tone": "说话语气"
    }
  ],
  "risks": ["风险点1", "风险点2", ...]
}

注意：dialogues 数组必须包含所有对话，按时间顺序排列，不要遗漏任何对话。"""
        
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
        
        # 解析对话列表
        dialogues_list = []
        if "dialogues" in analysis_data:
            for dialogue in analysis_data["dialogues"]:
                dialogues_list.append(DialogueItem(
                    speaker=dialogue.get("speaker", "未知"),
                    content=dialogue.get("content", ""),
                    tone=dialogue.get("tone", "未知")
                ))
        
        # 验证并构建返回数据
        result = AudioAnalysisResponse(
            speaker_count=analysis_data.get("speaker_count", 0),
            dialogues=dialogues_list,
            risks=analysis_data.get("risks", [])
        )
        
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
        
        # 调用内部函数分析
        return await analyze_audio_from_path(temp_file_path, file.filename or "audio.m4a")
        
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


@app.post("/api/v1/audio/upload")
async def upload_audio_api(
    file: UploadFile = File(...),
    title: Optional[str] = None
):
    """上传音频文件并开始分析"""
    import asyncio
    from datetime import datetime
    
    try:
        session_id = str(uuid.uuid4())
        
        if not title:
            formatter = datetime.now().strftime("%H:%M")
            title = f"录音 {formatter}"
        
        start_time = datetime.now()
        task_data = {
            "session_id": session_id,
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
        
        # 读取文件内容并保存到临时文件（必须在异步任务之前读取，因为 UploadFile 只能读取一次）
        file_content = await file.read()
        file_filename = file.filename or "audio.m4a"
        file_ext = Path(file_filename).suffix.lower() if file_filename else '.m4a'
        
        # 创建临时文件保存文件内容
        import tempfile
        temp_file = tempfile.NamedTemporaryFile(delete=False, suffix=file_ext)
        temp_file.write(file_content)
        temp_file.close()
        temp_file_path = temp_file.name
        
        # 异步分析（传递临时文件路径和文件名，确保所有参数都正确传递）
        logger.info(f"创建异步分析任务: session_id={session_id}, file_path={temp_file_path}, filename={file_filename}")
        asyncio.create_task(analyze_audio_async(session_id, temp_file_path, file_filename, task_data))
        
        return APIResponse(
            code=200,
            message="上传成功",
            data={
                "session_id": session_id,
                "audio_id": session_id,
                "title": title,
                "status": "analyzing",
                "estimated_duration": 300,
                "created_at": start_time.isoformat()
            },
            timestamp=datetime.now().isoformat()
        )
    except Exception as e:
        logger.error(f"上传音频失败: {e}")
        raise HTTPException(status_code=500, detail=f"上传失败: {str(e)}")


async def analyze_audio_async(session_id: str, temp_file_path: str, file_filename: str, task_data: dict):
    """异步分析音频文件"""
    from datetime import datetime
    
    try:
        logger.info(f"========== 开始异步分析音频 ==========")
        logger.info(f"session_id: {session_id}")
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
        
        # 直接使用临时文件路径调用 analyze_audio_from_path
        result = await analyze_audio_from_path(temp_file_path, file_filename or "audio.m4a")
        
        emotion_score = calculate_emotion_score(result)
        tags = generate_tags(result)
        
        end_time = datetime.now()
        duration = int((end_time - datetime.fromisoformat(task_data["start_time"])).total_seconds())
        
        task_data.update({
            "end_time": end_time.isoformat(),
            "duration": duration,
            "status": "archived",
            "emotion_score": emotion_score,
            "speaker_count": result.speaker_count,
            "tags": tags,
            "updated_at": end_time.isoformat()
        })
        
        analysis_storage[session_id] = {
            "dialogues": [d.dict() for d in result.dialogues],
            "risks": result.risks
        }
        
        logger.info(f"任务 {session_id} 分析完成")
    except Exception as e:
        logger.error(f"分析音频失败: {e}")
        logger.error(traceback.format_exc())
        task_data["status"] = "failed"
        task_data["updated_at"] = datetime.now().isoformat()
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
    status: Optional[str] = None
):
    """获取任务列表"""
    from datetime import datetime
    
    try:
        all_tasks = list(tasks_storage.values())
        filtered_tasks = all_tasks
        
        if date:
            target_date = datetime.fromisoformat(date).date()
            filtered_tasks = [
                t for t in filtered_tasks
                if datetime.fromisoformat(t["start_time"]).date() == target_date
            ]
        
        if status:
            filtered_tasks = [t for t in filtered_tasks if t["status"] == status]
        
        filtered_tasks.sort(key=lambda x: x["created_at"], reverse=True)
        
        total = len(filtered_tasks)
        start = (page - 1) * page_size
        end = start + page_size
        paginated_tasks = filtered_tasks[start:end]
        
        task_items = [
            TaskItem(
                session_id=t["session_id"],
                title=t["title"],
                start_time=t["start_time"],
                end_time=t.get("end_time"),
                duration=t["duration"],
                tags=t["tags"],
                status=t["status"],
                emotion_score=t.get("emotion_score"),
                speaker_count=t.get("speaker_count")
            )
            for t in paginated_tasks
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
        raise HTTPException(status_code=500, detail=f"获取列表失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}")
async def get_task_detail(session_id: str):
    """获取任务详情"""
    from datetime import datetime
    
    try:
        task_data = tasks_storage.get(session_id)
        if not task_data:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        analysis_result = analysis_storage.get(session_id, {})
        
        detail = TaskDetailResponse(
            session_id=task_data["session_id"],
            title=task_data["title"],
            start_time=task_data["start_time"],
            end_time=task_data.get("end_time"),
            duration=task_data["duration"],
            tags=task_data["tags"],
            status=task_data["status"],
            emotion_score=task_data.get("emotion_score"),
            speaker_count=task_data.get("speaker_count"),
            dialogues=analysis_result.get("dialogues", []),
            risks=analysis_result.get("risks", []),
            created_at=task_data["created_at"],
            updated_at=task_data["updated_at"]
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
        raise HTTPException(status_code=500, detail=f"获取详情失败: {str(e)}")


@app.get("/api/v1/tasks/sessions/{session_id}/status")
async def get_task_status(session_id: str):
    """查询任务分析状态"""
    from datetime import datetime
    
    try:
        task_data = tasks_storage.get(session_id)
        if not task_data:
            raise HTTPException(status_code=404, detail="任务不存在")
        
        return APIResponse(
            code=200,
            message="success",
            data={
                "session_id": session_id,
                "status": task_data["status"],
                "progress": 1.0 if task_data["status"] == "archived" else 0.5,
                "estimated_time_remaining": 0 if task_data["status"] == "archived" else 30,
                "updated_at": task_data["updated_at"]
            },
            timestamp=datetime.now().isoformat()
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"获取任务状态失败: {e}")
        raise HTTPException(status_code=500, detail=f"获取状态失败: {str(e)}")


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


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)

