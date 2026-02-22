"""
用户偏好存储（文件持久化，供自动策略生成读取 image_style）
"""
import os
import json
import logging

logger = logging.getLogger(__name__)

PREFERENCES_DIR = os.path.expanduser("~/gemini-audio-service/data")
PREFERENCES_FILE = os.path.join(PREFERENCES_DIR, "user_preferences.json")


def _ensure_dir():
    os.makedirs(PREFERENCES_DIR, exist_ok=True)


def _load_all() -> dict:
    _ensure_dir()
    if not os.path.isfile(PREFERENCES_FILE):
        return {}
    try:
        with open(PREFERENCES_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        logger.warning(f"读取用户偏好失败: {e}")
        return {}


def _save_all(data: dict):
    _ensure_dir()
    try:
        with open(PREFERENCES_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception as e:
        logger.warning(f"保存用户偏好失败: {e}")


def get_user_image_style(user_id: str) -> str | None:
    """获取用户的图片风格偏好，无则返回 None（使用默认 ghibli）"""
    data = _load_all()
    prefs = data.get(user_id, {})
    return prefs.get("image_style")


def set_user_image_style(user_id: str, image_style: str):
    """设置用户的图片风格偏好"""
    data = _load_all()
    if user_id not in data:
        data[user_id] = {}
    data[user_id]["image_style"] = image_style
    _save_all(data)
    logger.info(f"[用户偏好] user_id={user_id} image_style={image_style}")
