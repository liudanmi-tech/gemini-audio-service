#!/usr/bin/env python3
"""
家庭技能子技能封面图生成脚本（8张）
- 风格：皮克斯 3D，东亚人物面孔
- 覆盖：family_relationship (4) / education_communication (4)
"""

import os, sys, time, re, logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("gen_family_sub")

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
    # ── family_relationship ──────────────────────────────────────────────
    {
        "skill_id": "couple_communication",
        "skill_md_path": "skills/family_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻坐在温暖的客厅沙发上，夜灯柔和。"
            "丈夫侧身面向妻子，表情真诚专注地倾听；妻子眼中有泪光，嘴角微微上扬，感到被深深理解。"
            "丈夫轻轻握住妻子的手，两人之间有一种无声的情感共鸣。"
            "背景是家庭照片墙和暖黄灯光，整体传递「真正被听见」的治愈与亲密感。"
        ),
    },
    {
        "skill_id": "couple_conflict",
        "skill_md_path": "skills/family_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻刚刚经历激烈争吵后，两人背对背坐在客厅两端，各自沉默。"
            "过了一会儿，丈夫缓缓转过身，表情从倔强变为疲惫和悔意，轻轻开口。"
            "妻子先是没有回应，然后慢慢侧过头，眼睛里有委屈也有一丝软化。"
            "窗外有月光透入，整体画面传递「冰山消融、关系修复」的转折瞬间。"
        ),
    },
    {
        "skill_id": "family_decision",
        "skill_md_path": "skills/family_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻坐在餐桌前，桌上摆着房产资料和笔记本，两人面对面认真讨论。"
            "丈夫在纸上画图解释，妻子认真听并提问，两人的手指向同一张纸，神情专注而平等。"
            "孩子在一旁玩耍，温馨家庭氛围。整体传递「共同商量、一起扛」的家庭合力感，光线明亮温暖。"
        ),
    },
    {
        "skill_id": "inlaw_relationship",
        "skill_md_path": "skills/family_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一个中国三代家庭：婆婆、丈夫、妻子在客厅，丈夫站在中间，一手搀着母亲，一手拉着妻子，"
            "表情温和坚定，用眼神和姿态在两代人之间建立桥梁。"
            "婆婆表情从紧绷到微微释然，妻子感到被支持，微微颔首。"
            "画面传递「丈夫承担中间协调责任，三代和谐边界」的家庭关系图景。"
        ),
    },

    # ── education_communication ──────────────────────────────────────────
    {
        "skill_id": "learning_motivation",
        "skill_md_path": "skills/education_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国妈妈蹲下身来，与 9 岁左右的孩子平视，眼神温柔充满好奇。"
            "她手指着孩子的作业本，表情是引导提问而非批评，孩子眼睛里重新点燃了思考的光。"
            "书桌旁阳光透过窗户洒入，书本彩笔散落，整体氛围温暖充满希望，"
            "传递「蹲下来引导，孩子自然爱学习」的教育哲学。"
        ),
    },
    {
        "skill_id": "behavior_guidance",
        "skill_md_path": "skills/education_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国爸爸平静地坐在 7 岁女儿面前，桌上有一张家庭规则计划表。"
            "他给女儿提供两个选项，女儿神情从抵触变为若有所思，最终主动指向了一个选项。"
            "爸爸微笑点头，整个氛围轻松有序，没有争吵和眼泪。"
            "背景是整洁温馨的家庭书房，传递「给孩子选择权，行为自然改变」的教育智慧。"
        ),
    },
    {
        "skill_id": "teen_communication",
        "skill_md_path": "skills/education_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国妈妈和 15 岁的儿子并排坐在台阶上，夜色中只有路灯。"
            "妈妈没有质问，而是先分享了自己年轻时的一个故事，表情放松真诚。"
            "儿子从一开始看手机到放下手机，侧过头开始倾听，表情从防备逐渐打开。"
            "画面传递「放下说教、平等分享，青春期孩子才会开口」的沟通智慧。"
        ),
    },
    {
        "skill_id": "emotional_support",
        "skill_md_path": "skills/education_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国爸爸蹲在 10 岁女儿面前，女儿因考试失利正在哭泣。"
            "爸爸没有说「没事下次好好考」，而是静静地把女儿抱住，轻轻拍背。"
            "过了一会儿，女儿开始说话，爸爸专注倾听，表情充满理解和温柔。"
            "暖黄的房间灯光下，画面传递「先被接纳情绪，才能真正打开心扉」的亲子治愈瞬间。"
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
    """将 image_url 写入对应 sub_skill 的 cover_image 字段"""
    path = Path(md_path)
    content = path.read_text(encoding="utf-8")
    # 匹配 sub_skill 块内的 cover_image: "" 并替换
    pattern = rf'(  - id: {re.escape(skill_id)}\n(?:(?!  - id:)[\s\S])*?    cover_image:) ""'
    new_content = re.sub(pattern, rf'\1 "{image_url}"', content)
    if new_content == content:
        # 尝试替换已有 URL
        pattern2 = rf'(  - id: {re.escape(skill_id)}\n(?:(?!  - id:)[\s\S])*?    cover_image:) "https?://[^"]*"'
        new_content = re.sub(pattern2, rf'\1 "{image_url}"', content)
    if new_content == content:
        logger.error(f"❌ 未找到 {skill_id} 的 cover_image 字段")
        return
    path.write_text(new_content, encoding="utf-8")
    logger.info(f"✅ 已写入 {md_path}: {skill_id}.cover_image")


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
