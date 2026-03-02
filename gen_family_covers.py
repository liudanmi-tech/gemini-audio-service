#!/usr/bin/env python3
"""
家庭技能封面图生成脚本
- 风格：皮克斯 3D，东亚人物面孔
- 覆盖：family_relationship / education_communication
"""

import os, sys, time, re, logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("gen_family_covers")

from dotenv import load_dotenv
load_dotenv()

import google.generativeai as genai
import oss2

GEMINI_API_KEY  = os.getenv("GEMINI_API_KEY", "")
OSS_ACCESS_KEY  = os.getenv("OSS_ACCESS_KEY_ID", "")
OSS_SECRET_KEY  = os.getenv("OSS_ACCESS_KEY_SECRET", "")
OSS_ENDPOINT    = os.getenv("OSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com")
OSS_BUCKET_NAME = os.getenv("OSS_BUCKET_NAME", "geminipicture2")

genai.configure(api_key=GEMINI_API_KEY)
auth       = oss2.Auth(OSS_ACCESS_KEY, OSS_SECRET_KEY)
oss_bucket = oss2.Bucket(auth, OSS_ENDPOINT, OSS_BUCKET_NAME)

IMAGE_GEN_MODEL = "gemini-3.1-flash-image-preview"

ASIAN_TAG = (
    "所有人物均为东亚面孔（中国人），黑色直发，五官清秀自然。"
    "皮克斯 3D 动画风格：圆润角色建模、柔和体积光、细腻 PBR 材质、情感化表情，"
    "类似《寻梦环游记》《心灵奇旅》的照明与质感。"
)

TARGETS = [
    {
        "skill_id": "family_relationship",
        "skill_md_path": "skills/family_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻坐在温暖的客厅沙发上，夜灯柔和，氛围亲密安静。"
            "丈夫侧身面向妻子，表情真诚专注地倾听；妻子眼中有泪光，但嘴角微微上扬，"
            "感到被深深理解。丈夫轻轻握住妻子的手，两人之间有一种无声的情感共鸣。"
            "背景是家庭照片墙和暖黄灯光，整体传递「真正被听见」的治愈与亲密感。"
        ),
    },
    {
        "skill_id": "education_communication",
        "skill_md_path": "skills/education_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国妈妈蹲下身来，与 8 岁左右的孩子平视，眼神温柔而充满好奇。"
            "她手指着孩子的作业本，表情不是批评而是引导提问，孩子眼睛里重新点燃了思考的光。"
            "书桌旁阳光透过窗户洒入，书本和彩笔散落，整体氛围温暖、充满希望，"
            "传递出「蹲下来和孩子同频，才能真正引导」的教育哲学。"
        ),
    },
]


def upload_to_oss(image_bytes: bytes, oss_key: str) -> str | None:
    try:
        oss_bucket.put_object(oss_key, image_bytes, headers={"Content-Type": "image/png"})
        logger.info(f"✅ 上传: {oss_key} ({len(image_bytes):,} bytes)")
        return f"https://{OSS_BUCKET_NAME}.{OSS_ENDPOINT}/{oss_key}"
    except Exception as e:
        logger.error(f"❌ 上传失败: {e}")
        return None


def generate_cover(prompt: str, skill_id: str, attempt: int = 0) -> bytes | None:
    model = genai.GenerativeModel(IMAGE_GEN_MODEL)
    logger.info(f"[{skill_id}] 生成中... (attempt {attempt+1})")
    start = time.time()
    response = model.generate_content(prompt)
    logger.info(f"[{skill_id}] 耗时 {time.time()-start:.1f}s")
    for part in response.parts:
        if part.inline_data is not None:
            logger.info(f"[{skill_id}] ✅ {len(part.inline_data.data):,} bytes")
            return part.inline_data.data
    logger.warning(f"[{skill_id}] ⚠️ 无图片数据")
    return None


def update_skill_md(md_path: str, skill_id: str, image_url: str):
    path = Path(md_path)
    content = path.read_text(encoding="utf-8")
    # 替换 cover_image: "" 或已有 URL
    new_content = re.sub(
        r'^cover_image:.*$',
        f'cover_image: "{image_url}"',
        content,
        flags=re.MULTILINE
    )
    if new_content == content:
        logger.error(f"❌ 未找到 cover_image 字段: {md_path}")
        return
    path.write_text(new_content, encoding="utf-8")
    logger.info(f"✅ 已写入 {md_path}: cover_image")


def main():
    results = {}
    for t in TARGETS:
        sid = t["skill_id"]
        logger.info(f"\n{'='*50}\n处理: {sid}")
        image_bytes = None
        for attempt in range(3):
            try:
                image_bytes = generate_cover(t["image_prompt"], sid, attempt)
                if image_bytes:
                    break
            except Exception as e:
                logger.error(f"[{sid}] 异常 (attempt {attempt+1}): {e}")
                if attempt < 2:
                    time.sleep(3)
        if not image_bytes:
            results[sid] = None
            continue
        oss_key = f"skill_covers/{sid}_pixar.png"
        url = upload_to_oss(image_bytes, oss_key)
        results[sid] = url
        if url:
            update_skill_md(t["skill_md_path"], sid, url)
        time.sleep(2)

    logger.info(f"\n{'='*50}\n汇总：")
    for sid, url in results.items():
        logger.info(f"  {sid}: {'✅ ' + url if url else '❌ 失败'}")


if __name__ == "__main__":
    main()
