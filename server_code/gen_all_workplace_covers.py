#!/usr/bin/env python3
"""
批量生成剩余 15 个职场技能封面图
- 风格：皮克斯 3D，东亚人物面孔
- 覆盖：workplace_scenario / workplace_psychology / workplace_career / workplace_capability
"""

import os, sys, time, logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("gen_all_workplace")

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
    # ── workplace_scenario ──────────────────────────────────────────────────
    {
        "skill_id": "conflict_resolution",
        "skill_md_path": "skills/workplace_scenario/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "两位中国职场人站在现代会议室里，最初剑拔弩张、相互对视，"
            "其中一人主动伸出手，表情从紧张转为真诚和解。"
            "另一人眼神中闪过惊讶后逐渐松弛，握手迎接。"
            "暖光从窗外斜入，背景是玻璃隔断和白板，整体传递「化对抗为合作」的转折时刻。"
        ),
    },
    {
        "skill_id": "negotiation",
        "skill_md_path": "skills/workplace_scenario/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "两位亚洲商务人士面对面坐在谈判桌两侧，桌上摆着合同文件和数据报表。"
            "双方表情沉稳自信，微微前倾，眼神交汇中透出智慧博弈的张力。"
            "画面中心隐约有天平图案，象征利益平衡，整体色调温暖专业。"
        ),
    },
    {
        "skill_id": "presentation",
        "skill_md_path": "skills/workplace_scenario/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位自信的中国职场人站在大型投影屏幕前，手持遥控笔，"
            "面对台下几位认真聆听的高管。屏幕上呈现清晰的金字塔结构图表。"
            "演讲者表情专注有力，灯光聚焦，传递出「结论先行、打动听众」的专业氛围。"
        ),
    },
    {
        "skill_id": "small_talk",
        "skill_md_path": "skills/workplace_scenario/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "三四位中国同事在明亮的办公室休息区轻松闲聊，手持咖啡杯，"
            "表情自然愉快，有人在大笑，有人认真倾听。"
            "阳光透过大窗洒入，绿植点缀，传递出轻松的职场人际关系与非正式社交的温暖氛围。"
        ),
    },
    {
        "skill_id": "crisis_management",
        "skill_md_path": "skills/workplace_scenario/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国职场管理者在紧张的危机会议室中镇定自若地站立，"
            "周围同事面露焦虑，他却表情沉稳，手指白板上的应急方案。"
            "窗外隐约有风暴意象，室内灯光聚焦于他，传递出「危机中的冷静领导力」。"
        ),
    },

    # ── workplace_psychology ─────────────────────────────────────────────────
    {
        "skill_id": "defensive",
        "skill_md_path": "skills/workplace_psychology/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国职场人站得稳稳的，面对试图越界的同事，"
            "用平静而坚定的眼神和手势（手掌向前，礼貌示停）设定边界。"
            "表情不是愤怒，而是从容自信。周身有淡淡的光晕，象征内心边界的保护力量。"
        ),
    },
    {
        "skill_id": "offensive",
        "skill_md_path": "skills/workplace_psychology/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位充满活力的中国职场人大步向前走，手持一份提案文件，"
            "表情充满决心和锐气。背景是上升的折线图和城市天际线，"
            "光线从前方照来，象征主动出击、打破惯性、向前冲的进攻态势。"
        ),
    },
    {
        "skill_id": "constructive",
        "skill_md_path": "skills/workplace_psychology/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "四位来自不同背景的中国职场人围成一圈，各自手持一块拼图，"
            "正在将它们拼合成一个完整的图案。每人脸上都有合作成功的愉快与成就感。"
            "温暖的阳光从中心向外辐射，象征「把蛋糕做大、共建双赢」。"
        ),
    },
    {
        "skill_id": "healing",
        "skill_md_path": "skills/workplace_psychology/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国职场人温柔地倾身向前，专注地倾听对面情绪低落的同事说话，"
            "眼神充满关怀与共情，轻轻将手放在对方肩膀。"
            "室内光线柔和温暖，背景略虚，画面传递出「被真正听见」的治愈力量。"
        ),
    },

    # ── workplace_career ─────────────────────────────────────────────────────
    {
        "skill_id": "rookie",
        "skill_md_path": "skills/workplace_career/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位刚入职的年轻中国职场人，抱着笔记本，带着新奇与期待的眼神"
            "踏入宽敞明亮的现代办公室。旁边的老员工微笑引导，整体氛围充满希望与朝气。"
            "新人表情认真而略带紧张，传递出「头 90 天留下好印象」的起点时刻。"
        ),
    },
    {
        "skill_id": "core_manager",
        "skill_md_path": "skills/workplace_career/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国中层管理者站在团队与高管之间，左手指向上方的决策层，"
            "右手转向身后的团队成员，表情沉稳自信，承上启下。"
            "画面构图呈「桥梁」形态，传递出「夹心层」连接上下、协调全局的关键角色。"
        ),
    },
    {
        "skill_id": "executive",
        "skill_md_path": "skills/workplace_career/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位成熟的中国高管站在高台上，面向台下大批充满热情的员工发表演讲，"
            "眼神坚定而有感召力，背后是宏大的城市天际线与公司愿景投影。"
            "光线从上方落下，如舞台聚光，传递出高管「让组织相信未来」的领袖气场。"
        ),
    },

    # ── workplace_capability ─────────────────────────────────────────────────
    {
        "skill_id": "logical_thinking",
        "skill_md_path": "skills/workplace_capability/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国职场人站在透明白板前，白板上呈现清晰的金字塔结构框架图，"
            "他手持马克笔，将复杂信息整理得井井有条。"
            "表情专注、思维清晰，周围的浮动几何图形象征结构化思维的力量与秩序。"
        ),
    },
    {
        "skill_id": "eq",
        "skill_md_path": "skills/workplace_capability/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国职场人站在团队中央，能感知到周围每个人的情绪状态——"
            "有人焦虑、有人兴奋、有人低落，他一一用眼神和表情回应，给予理解。"
            "画面中心有温暖的金色光晕向外扩散，象征情商与共情力如涟漪般影响周围。"
        ),
    },
    {
        "skill_id": "influence",
        "skill_md_path": "skills/workplace_capability/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位充满感召力的中国职场人慷慨陈词，话语如涟漪向外扩散，"
            "周围越来越多的同事被吸引，纷纷侧身倾听、点头认同。"
            "画面用同心圆涟漪视觉效果呈现影响力扩散，演讲者表情真诚有力，光从身前照来。"
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
    import re
    path = Path(md_path)
    content = path.read_text(encoding="utf-8")
    # 贪婪匹配该 skill_id 所在 block（到下一个 "  - id:" 或文件尾）
    pattern = rf"(  - id: {re.escape(skill_id)}\n)((?:(?!  - id:)[\s\S])*?)(    cover_color:.*\n)"
    def replacer(m):
        block_before = m.group(1) + m.group(2)
        color_line   = m.group(3)
        new_image    = f'    cover_image: "{image_url}"\n'
        return block_before + color_line + new_image
    new_content, n = re.subn(pattern, replacer, content)
    if n == 0:
        logger.error(f"❌ 未找到 {skill_id} 的 cover_color 行")
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
