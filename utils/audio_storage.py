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
    if audio_path and os.path.isfile(audio_path):
        return (audio_path, False)
    if not audio_url:
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
                import oss2
                auth = oss2.Auth(ak, sk)
                bucket = oss2.Bucket(auth, ep, bucket_name)
                bucket.get_object_to_file(oss_key, tmp.name)
                return (tmp.name, True)
            except Exception as e:
                logger.warning(f"OSS SDK 下载原音频失败: {e}")
            # 若 SDK 失败，下面不再用 urlretrieve 试同一 URL（通常也会 403）
            try:
                os.unlink(tmp.name)
            except Exception:
                pass
            return (None, False)
    # 公网 URL 或非本 bucket：用 urllib
    try:
        import urllib.request
        urllib.request.urlretrieve(audio_url, tmp.name)
        return (tmp.name, True)
    except Exception as e:
        logger.warning(f"下载原音频失败: {e}")
        try:
            os.unlink(tmp.name)
        except Exception:
            pass
    return (None, False)


def cut_audio_segment(local_path: str, start_sec: float, end_sec: float) -> bytes:
    """按时间戳剪切音频，返回片段字节。"""
    from pydub import AudioSegment
    start_ms = int(start_sec * 1000)
    end_ms = int(end_sec * 1000)
    if start_ms >= end_ms:
        raise ValueError("start_time 必须小于 end_time")
    audio = AudioSegment.from_file(local_path)
    clip = audio[start_ms:end_ms]
    buf = io.BytesIO()
    ext = os.path.splitext(local_path)[1].lower() or ".m4a"
    fmt = "mp4" if ext in (".m4a", ".mp4") else "mp3"
    clip.export(buf, format=fmt)
    return buf.getvalue()


def upload_segment_bytes(
    segment_bytes: bytes,
    user_id: str,
    session_id: str,
    segment_id: str,
    ext: str = ".m4a",
) -> str:
    """
    将片段字节上传到 OSS 或保存到本地，返回可访问的 URL 或本地路径。
    """
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
            bucket.put_object(oss_key, segment_bytes, headers={"Content-Type": "audio/mp4" if ext == ".m4a" else "application/octet-stream"})
            if _OSS_CDN_DOMAIN:
                return f"https://{_OSS_CDN_DOMAIN}/{oss_key}"
            if ep.startswith("http"):
                base = ep.rstrip("/")
            else:
                base = f"https://{bucket_name}.{ep}"
            return f"{base}/{oss_key}"
        except Exception as e:
            logger.warning(f"片段上传 OSS 失败，改用本地: {e}")
    os.makedirs(_SEGMENTS_DIR, exist_ok=True)
    local_path = os.path.join(_SEGMENTS_DIR, f"{segment_id}{ext}")
    with open(local_path, "wb") as f:
        f.write(segment_bytes)
    return local_path
