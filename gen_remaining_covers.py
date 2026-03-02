#!/usr/bin/env python3
"""
其他技能子技能封面图生成脚本（9张）
- brainstorm (3) / depression_prevention (3) / emotion_recognition (3)
- 风格：皮克斯 3D，东亚人物面孔
"""

import os, sys, time, re, logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("gen_remaining")

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
    # ── brainstorm ───────────────────────────────────────────────────────────
    {
        "skill_id": "divergent_thinking",
        "skill_md_path": "skills/brainstorm/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "三位中国职场人围在白板前，白板上有彩色射线状思维导图向四面发散。"
            "中间一位站起来兴奋地在白板写下新创意，眼神发光、手势活跃；"
            "另外两人也快速记录，表情充满被点燃的热情。"
            "整体氛围充满创意爆发的活力，暖白灯光，传递「让点子真正跑出来」的发散突破感。"
        ),
    },
    {
        "skill_id": "idea_filtering",
        "skill_md_path": "skills/brainstorm/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国职场女性站在贴满便利贴的玻璃墙前，便利贴五颜六色密密麻麻。"
            "她手中拿着一张金色便利贴，表情从迷茫变为笃定，"
            "背景光线渐渐聚焦于这一张，其他便利贴轻轻变暗。"
            "整体传递「从百个念头中找到那颗值钱的想法」的聚焦顿悟时刻。"
        ),
    },
    {
        "skill_id": "collaborative_dynamics",
        "skill_md_path": "skills/brainstorm/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "四位中国同事围坐圆桌，每人面前有不同颜色的创意卡片。"
            "桌子中间有一个发光的想法晶体，四人同时伸手触向它，"
            "脸上流露出协作碰撞的兴奋感，每人背景光晕各异但汇聚于中心。"
            "整体传递「不同思维碰撞出 1+1>10 的团队合力」的协同共创感。"
        ),
    },

    # ── depression_prevention ─────────────────────────────────────────────────
    {
        "skill_id": "defense_audit",
        "skill_md_path": "skills/depression_prevention/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国年轻男性独坐室内，面前有一面透明的镜子。"
            "镜子里的他伸出手，试图触碰真实的自己；真实的他表情冷静理智，"
            "但眼神中隐藏着疲惫和委屈。镜像中的他表情更温柔，手势更开放。"
            "窗外有柔和阳光，整体传递「看见防御，第一步是认识自己」的内省与疗愈感。"
        ),
    },
    {
        "skill_id": "cognitive_triad_check",
        "skill_md_path": "skills/depression_prevention/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国年轻女性面前有三盏灯（分别代表自我、世界、未来），"
            "两盏已经暗淡熄灭，第三盏摇曳微弱。"
            "她的手轻轻靠近那盏快熄灭的灯，表情充满专注与关怀，"
            "眼神温柔而坚定，灯的火焰在她手心的温度下微微变亮。"
            "整体传递「认知三极的早期检测，守护内心的光」的温暖预警感。"
        ),
    },
    {
        "skill_id": "early_warning_intervention",
        "skill_md_path": "skills/depression_prevention/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国年轻人站在黑暗与光明的交界处：身后是深蓝色阴影，"
            "面前是一扇虚掩的门，门缝透出温暖的金色光线。"
            "他/她手握门把，表情从迷茫转为坚定，脚步即将踏入光中。"
            "整体氛围温暖而充满希望，传递「在黑暗彻底降临前找到那道光」的早期干预力量。"
        ),
    },

    # ── emotion_recognition ──────────────────────────────────────────────────
    {
        "skill_id": "mood_radar",
        "skill_md_path": "skills/emotion_recognition/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国上班族坐在桌前，面前有一个情绪仪表盘的光屏，"
            "屏幕上显示叹气次数、笑声频率和今日情绪状态的可视化图表。"
            "他的表情从「嗯，还好」变为若有所思，意识到声音里写着真实情绪。"
            "背景是温馨的居家环境，暖黄灯光，传递「声音不骗人，情绪被看见」的洞察感。"
        ),
    },
    {
        "skill_id": "emotion_pattern",
        "skill_md_path": "skills/emotion_recognition/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国职场女性看着月历上的情绪曲线图（有红有绿起伏的折线），"
            "手指着其中一个规律性的低谷点，表情从困惑到恍然大悟。"
            "旁边有日光和暖光交替的窗户，象征情绪的高低潮。"
            "整体传递「发现情绪规律，才能真正掌控它」的洞见与掌控感。"
        ),
    },
    {
        "skill_id": "stress_barometer",
        "skill_md_path": "skills/emotion_recognition/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国上班族坐在办公桌前，桌旁有一个压力晴雨表从红色慢慢降至绿色。"
            "他的表情从紧绷慢慢舒展，双手从攥紧鼠标到自然放开，"
            "肩膀微微下沉，像是卸下一个无形的重担。"
            "整体传递「被看见的压力是可以被管理的」的释然与轻盈感。"
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
