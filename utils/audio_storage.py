"""
原音频与片段存储：获取原音频本地路径、上传片段到 OSS 或本地、剪切片段。
供 main 与 api/audio_segments 共用，避免循环导入。
"""
import io
import os
import tempfile
import logging
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

# 从环境变量读取 OSS 配置（与 main 一致）
_USE_OSS = os.getenv("USE_OSS", "true").lower() == "true"
_OSS_CDN_DOMAIN = os.getenv("OSS_CDN_DOMAIN")
_OSS_ENDPOINT = os.getenv("OSS_ENDPOINT")
_OSS_BUCKET_NAME = os.getenv("OSS_BUCKET_NAME")
_AUDIO_STORAGE_DIR = os.getenv("AUDIO_STORAGE_DIR", "data/audio/sessions")
_SEGMENTS_DIR = os.getenv("AUDIO_SEGMENTS_DIR", "data/audio/segments")


def _oss_key_from_url(audio_url: str) -> Optional[str]:
    """从本 bucket 的 OSS URL 解析 object key（阿里云格式 https://bucket.oss-region.aliyuncs.com/key）。"""
    if not _OSS_BUCKET_NAME or not audio_url or not audio_url.startswith("http"):
        return None
    try:
        from urllib.parse import urlparse
        p = urlparse(audio_url)
        path = (p.path or "").lstrip("/")
        if not path:
            return None
        # 仅当 URL 指向本 bucket 时才用 SDK 下载（避免误用 SDK 下载第三方 URL）
        if _OSS_BUCKET_NAME not in (p.netloc or ""):
            return None
        return path
    except Exception:
        return None


def get_session_audio_local_path(audio_url: Optional[str], audio_path: Optional[str]) -> Tuple[Optional[str], bool]:
    """
    返回可读的本地文件路径。若仅有 OSS URL 则下载到临时文件。
    本 bucket 私有读时用 OSS SDK 下载；公网 URL 用 urllib。
    Returns:
        (local_path, is_temp): is_temp 为 True 时调用方需在用完后删除该文件。
    """
    logger.info("[get_session_audio] 入参: audio_path=%s audio_url=%s", audio_path, bool(audio_url))
    if audio_path and os.path.isfile(audio_path):
        logger.info("[get_session_audio] 使用本地路径: %s", audio_path)
        return (audio_path, False)
    if audio_path and not os.path.isfile(audio_path):
        logger.warning("[get_session_audio] 本地路径不存在: %s", audio_path)
        return (None, False)
    if not audio_url:
        logger.warning("[get_session_audio] 无 audio_url")
        return (None, False)
    suffix = ".m4a"
    if ".mp3" in (audio_url or ""):
        suffix = ".mp3"
    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
    tmp.close()
    # 优先用 OSS SDK 下载（私有 bucket 必须）
    oss_key = _oss_key_from_url(audio_url)
    if oss_key and _USE_OSS:
        ak = os.getenv("OSS_ACCESS_KEY_ID")
        sk = os.getenv("OSS_ACCESS_KEY_SECRET")
        ep = os.getenv("OSS_ENDPOINT")
        bucket_name = os.getenv("OSS_BUCKET_NAME")
        if all([ak, sk, ep, bucket_name]):
            try:
                logger.info("[get_session_audio] OSS 下载开始: key=%s", oss_key)
                import oss2
                auth = oss2.Auth(ak, sk)
                bucket = oss2.Bucket(auth, ep, bucket_name)
                bucket.get_object_to_file(oss_key, tmp.name)
                size = os.path.getsize(tmp.name)
                logger.info("[get_session_audio] OSS 下载成功: size=%d bytes", size)
                return (tmp.name, True)
            except Exception as e:
                logger.exception("[get_session_audio] OSS SDK 下载原音频失败: %s", e)
            # 若 SDK 失败，下面不再用 urlretrieve 试同一 URL（通常也会 403）
            try:
                os.unlink(tmp.name)
            except Exception:
                pass
            return (None, False)
    # 公网 URL 或非本 bucket：用 urllib
    try:
        logger.info("[get_session_audio] urllib 下载开始: url=%s", audio_url[:80] + "..." if len(audio_url or "") > 80 else audio_url)
        import urllib.request
        urllib.request.urlretrieve(audio_url, tmp.name)
        size = os.path.getsize(tmp.name)
        logger.info("[get_session_audio] urllib 下载成功: size=%d bytes", size)
        return (tmp.name, True)
    except Exception as e:
        logger.exception("[get_session_audio] 下载原音频失败: %s", e)
        try:
            os.unlink(tmp.name)
        except Exception:
            pass
    return (None, False)


def cut_audio_segment(local_path: str, start_sec: float, end_sec: float) -> bytes:
    """
    按时间戳剪切音频，返回片段字节。
    使用 ffmpeg -ss -t 只解码目标区间，避免 pydub 加载全文件导致的超时（30MB mp3 需 1–2 分钟）。
    """
    import time
    import subprocess
    t0 = time.time()
    logger.info("[cut_audio_segment] 开始: path=%s start=%.1f end=%.1f", local_path[:60] if len(local_path) > 60 else local_path, start_sec, end_sec)
    if start_sec >= end_sec:
        raise ValueError("start_time 必须小于 end_time")
    duration_sec = end_sec - start_sec
    ext = os.path.splitext(local_path)[1].lower() or ".m4a"
    out_fmt = "mp4" if ext in (".m4a", ".mp4") else "mp3"
    # -ss 放 -i 前可加速 seek；-t 限制时长；-acodec copy 不可靠（不同编码），改用重新编码保证兼容
    cmd = [
        "ffmpeg", "-y",
        "-ss", str(start_sec),   # 在解码前 seek，只处理目标区间
        "-i", local_path,
        "-t", str(duration_sec),
        "-c:a", "libmp3lame" if out_fmt == "mp3" else "aac",
        "-vn", "-f", out_fmt,
        "pipe:1"
    ]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            timeout=60,
            check=False
        )
        if result.returncode != 0:
            err = (result.stderr or b"").decode("utf-8", errors="replace")
            raise RuntimeError(f"ffmpeg 失败 (code={result.returncode}): {err[:500]}")
        out = result.stdout
        if not out:
            raise RuntimeError("ffmpeg 输出为空")
        logger.info("[cut_audio_segment] 完成: size=%d bytes 耗时=%.2fs", len(out), time.time() - t0)
        return out
    except subprocess.TimeoutExpired:
        raise RuntimeError("ffmpeg 处理超时(60s)，请检查音频文件是否损坏")


def upload_segment_bytes(
    segment_bytes: bytes,
    user_id: str,
    session_id: str,
    segment_id: str,
    ext: str = ".m4a",
) -> str:
    """
    将片段字节上传到 OSS，返回可访问的 URL。不设置 x-oss-object-acl，避免 "Put public object acl is not allowed"。
    OSS 失败时抛出异常，供上层转为 503（客户端无法使用本地路径）。
    """
    import time
    t0 = time.time()
    logger.info("[upload_segment] 开始: size=%d user=%s session=%s", len(segment_bytes), user_id, session_id)
    if _USE_OSS:
        try:
            import oss2
            ak = os.getenv("OSS_ACCESS_KEY_ID")
            sk = os.getenv("OSS_ACCESS_KEY_SECRET")
            ep = os.getenv("OSS_ENDPOINT")
            bucket_name = os.getenv("OSS_BUCKET_NAME")
            if not all([ak, sk, ep, bucket_name]):
                raise ValueError("OSS 配置不完整")
            auth = oss2.Auth(ak, sk)
            bucket = oss2.Bucket(auth, ep, bucket_name)
            oss_key = f"sessions/{user_id}/{session_id}/segments/{segment_id}{ext}"
            # 仅设置 Content-Type，不设置 x-oss-object-acl（阿里云禁止时会导致 403）
            headers = {"Content-Type": "audio/mp4" if ext == ".m4a" else "application/octet-stream"}
            bucket.put_object(oss_key, segment_bytes, headers=headers)
            logger.info("[upload_segment] OSS 成功: key=%s size=%d 耗时=%.2fs", oss_key, len(segment_bytes), time.time() - t0)
            if _OSS_CDN_DOMAIN:
                return f"https://{_OSS_CDN_DOMAIN}/{oss_key}"
            if ep.startswith("http"):
                base = ep.rstrip("/")
            else:
                base = f"https://{bucket_name}.{ep}"
            return f"{base}/{oss_key}"
        except Exception as e:
            logger.exception("[upload_segment] OSS 失败: %s", e)
            raise
    # OSS 未启用时，本地路径对客户端不可用，应视为配置错误
    raise ValueError("OSS 未启用，无法上传片段；客户端需要可访问的 URL")
