#!/usr/bin/env python3
"""
职场技能封面图生成脚本
- 风格：皮克斯（pixar）
- 目标：workplace_role 的前 4 个子技能
- 图片上传 OSS 后，将 URL 写回对应 SKILL.md 的 cover_image 字段
- 用法：python gen_skill_covers.py
"""

import os, sys, time, logging, re
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("gen_skill_covers")

# ─── 加载环境变量（与 main.py 同目录运行）────────────────────────────────────
from dotenv import load_dotenv
load_dotenv()

import google.generativeai as genai
import oss2

GEMINI_API_KEY   = os.getenv("GEMINI_API_KEY", "")
OSS_ACCESS_KEY   = os.getenv("OSS_ACCESS_KEY_ID", "")
OSS_SECRET_KEY   = os.getenv("OSS_ACCESS_KEY_SECRET", "")
OSS_ENDPOINT     = os.getenv("OSS_ENDPOINT", "oss-cn-beijing.aliyuncs.com")
OSS_BUCKET_NAME  = os.getenv("OSS_BUCKET_NAME", "geminipicture2")
OSS_CDN_DOMAIN   = os.getenv("OSS_CDN_DOMAIN", "")

genai.configure(api_key=GEMINI_API_KEY)

auth       = oss2.Auth(OSS_ACCESS_KEY, OSS_SECRET_KEY)
oss_bucket = oss2.Bucket(auth, OSS_ENDPOINT, OSS_BUCKET_NAME)

IMAGE_GEN_MODEL = "gemini-3.1-flash-image-preview"   # Nano Banana 2

# 皮克斯风格前缀（来自 main.py IMAGE_STYLE_MAP）
PIXAR_PREFIX = (
    "皮克斯 3D 动画风格：圆润角色建模、柔和体积光、细腻 PBR 材质、情感化表情。"
    "类似《寻梦环游记》《心灵奇旅》的照明与质感。"
)

# ─── 要生成的 4 张技能封面 ────────────────────────────────────────────────────
# 字段：skill_id, skill_md_path, image_prompt, cover_color
TARGETS = [
    {
        "skill_id":      "managing_up",
        "skill_md_path": "skills/workplace_role/SKILL.md",
        "image_prompt": (
            "一位年轻职场人站在宽敞的现代办公室中，手持一份精心准备的汇报方案，"
            "自信地面对坐在大班台后的成熟上司。上司微微前倾、神情认真。"
            "窗外是都市夜景，室内暖光柔和。构图强调两人之间的信任感与权力差异，"
            "年轻人姿态谦逊而自信，整体氛围专业向上。"
        ),
    },
    {
        "skill_id":      "managing_down",
        "skill_md_path": "skills/workplace_role/SKILL.md",
        "image_prompt": (
            "一位中年女性领导者站在白板前，面对三位充满活力的年轻团队成员。"
            "她手指白板上的项目规划图，表情鼓励而温暖；团队成员们认真记录，眼神充满干劲。"
            "现代开放式办公室，绿植点缀，自然光线充足。"
            "画面传递出领导赋能、团队蓬勃的积极氛围。"
        ),
    },
    {
        "skill_id":      "peer_collaboration",
        "skill_md_path": "skills/workplace_role/SKILL.md",
        "image_prompt": (
            "四位来自不同部门的职场人围坐在圆形会议桌旁，桌上摆着笔记本和咖啡杯。"
            "他们各持不同颜色的便利贴，共同拼贴在中央的看板上，表情专注而愉快。"
            "阳光透过落地窗洒入，整体色调明快活力。"
            "画面强调平等协作、无层级的横向沟通氛围。"
        ),
    },
    {
        "skill_id":      "external_communication",
        "skill_md_path": "skills/workplace_role/SKILL.md",
        "image_prompt": (
            "一位西装笔挺的商务人士在玻璃幕墙会议室内与客户握手，"
            "背景是城市天际线与现代商务楼。双方面带笑容，握手姿态坚定友好，"
            "桌上摆放着合作协议文件和品牌展示册。"
            "画面传递出专业、信任与双赢的对外沟通氛围，光线明亮温暖。"
        ),
    },
]


def upload_to_oss(image_bytes: bytes, oss_key: str) -> str | None:
    """上传图片到 OSS，返回可访问的 URL"""
    try:
        headers = {"Content-Type": "image/png"}
        oss_bucket.put_object(oss_key, image_bytes, headers=headers)
        logger.info(f"✅ 上传成功: {oss_key} ({len(image_bytes)} bytes)")

        if OSS_CDN_DOMAIN:
            return f"https://{OSS_CDN_DOMAIN}/{oss_key}"
        endpoint = OSS_ENDPOINT if OSS_ENDPOINT.startswith("http") else f"https://{OSS_ENDPOINT}"
        endpoint = endpoint.replace("http://", "https://")
        return f"https://{OSS_BUCKET_NAME}.{OSS_ENDPOINT.lstrip('https://').lstrip('http://')}/{oss_key}"
    except Exception as e:
        logger.error(f"❌ OSS 上传失败: {e}")
        return None


def generate_cover(prompt: str, skill_id: str, attempt: int = 0) -> bytes | None:
    """调用 Nano Banana 2 生成技能封面图"""
    model = genai.GenerativeModel(IMAGE_GEN_MODEL)

    # 加载皮克斯风格参考图（如果有）
    contents = []
    pixar_ref = Path(__file__).parent / "style_references" / "pixar_ref.jpg"
    if pixar_ref.exists():
        contents.append({"mime_type": "image/jpeg", "data": pixar_ref.read_bytes()})
        full_prompt = (
            "请严格参考第一张图片所呈现的视觉风格（色调、光影、质感、构图）进行图片创作。\n\n"
            + PIXAR_PREFIX + prompt
        )
        logger.info(f"[{skill_id}] 已加载皮克斯风格参考图")
    else:
        full_prompt = PIXAR_PREFIX + prompt
        logger.info(f"[{skill_id}] 无风格参考图，使用纯文本 prompt")

    contents.append(full_prompt)

    logger.info(f"[{skill_id}] 开始生成封面... (attempt {attempt+1})")
    start = time.time()
    response = model.generate_content(contents)
    elapsed = time.time() - start
    logger.info(f"[{skill_id}] 生成耗时 {elapsed:.1f}s")

    for part in response.parts:
        if part.inline_data is not None:
            logger.info(f"[{skill_id}] ✅ 获取图片数据 {len(part.inline_data.data)} bytes")
            return part.inline_data.data

    logger.warning(f"[{skill_id}] ⚠️ 响应中无图片数据")
    return None


def update_skill_md_cover_image(md_path: str, skill_id: str, image_url: str):
    """
    将 image_url 写入 SKILL.md 对应 sub-skill 的 cover_image 字段。
    如果该 sub-skill 已有 cover_image 则替换，否则在 cover_color 行之后插入。
    """
    path = Path(md_path)
    content = path.read_text(encoding="utf-8")

    # 找到目标 sub-skill 的 id 行，在其后找 cover_color 并插入/替换 cover_image
    # 策略：在 "  - id: {skill_id}" 之后，下一个 "  - id:" 之前的区域操作
    pattern = rf"(  - id: {re.escape(skill_id)}\n(?:(?!  - id:).)*?)"
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        logger.error(f"❌ 在 {md_path} 中未找到 sub-skill id={skill_id}")
        return

    block = match.group(0)
    if "cover_image:" in block:
        # 替换已有的 cover_image
        new_block = re.sub(
            r"(    cover_image:).*",
            f"    cover_image: \"{image_url}\"",
            block
        )
    else:
        # 在 cover_color 行之后插入
        new_block = re.sub(
            r"(    cover_color:.*\n)",
            rf"\1    cover_image: \"{image_url}\"\n",
            block
        )

    new_content = content[:match.start()] + new_block + content[match.end():]
    path.write_text(new_content, encoding="utf-8")
    logger.info(f"✅ 已更新 {md_path}: {skill_id}.cover_image = {image_url}")


def main():
    results = {}

    for t in TARGETS:
        skill_id = t["skill_id"]
        logger.info(f"\n{'='*50}")
        logger.info(f"处理: {skill_id}")

        # 生成图片
        image_bytes = None
        for attempt in range(3):
            try:
                image_bytes = generate_cover(t["image_prompt"], skill_id, attempt)
                if image_bytes:
                    break
            except Exception as e:
                logger.error(f"[{skill_id}] 生成异常 (attempt {attempt+1}): {e}")
                if attempt < 2:
                    time.sleep(3)

        if not image_bytes:
            logger.error(f"[{skill_id}] ❌ 生成失败，跳过")
            results[skill_id] = None
            continue

        # 上传 OSS
        oss_key = f"skill_covers/{skill_id}_pixar.png"
        image_url = upload_to_oss(image_bytes, oss_key)
        if not image_url:
            logger.error(f"[{skill_id}] ❌ 上传失败，跳过")
            results[skill_id] = None
            continue

        results[skill_id] = image_url

        # 写回 SKILL.md
        update_skill_md_cover_image(t["skill_md_path"], skill_id, image_url)

        # 技能间稍作间隔，避免 API 限速
        time.sleep(2)

    logger.info(f"\n{'='*50}")
    logger.info("生成汇总：")
    for sid, url in results.items():
        status = f"✅ {url}" if url else "❌ 失败"
        logger.info(f"  {sid}: {status}")


if __name__ == "__main__":
    main()
