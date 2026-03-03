#!/usr/bin/env python3
"""
家庭技能扩展版封面图生成脚本（39张）
- 覆盖：child_behavior(3) / child_emotion(3) / couple_decision(3) / couple_finance(3)
         couple_intimacy(3) / elder_care(3) / family_boundary(3) / family_conflict(3)
         family_role(3) / household_division(3) / inlaw_relationship(3)
         study_pressure(3) / teen_communication(3)
- 风格：皮克斯 3D，东亚人物面孔
"""

import os, sys, time, re, logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("gen_family_ext")

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
    # ── child_behavior ───────────────────────────────────────────────────────
    {
        "skill_id": "behavior_decode",
        "skill_md_path": "skills/child_behavior/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国妈妈蹲下来，与 3 岁哭泣孩子平视，孩子刚刚摔了玩具在发脾气。"
            "妈妈不责备，而是眼神温柔专注，手轻轻放在孩子手臂上，表情充满好奇地问「发生什么了？」"
            "孩子在妈妈的关注下情绪慢慢平息，抬起头来看向妈妈。"
            "整体传递「读懂行为背后的需求，而非压制行为」的温暖亲子时刻。"
        ),
    },
    {
        "skill_id": "positive_discipline",
        "skill_md_path": "skills/child_behavior/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国爸爸平静地坐在地板上，面前有一张「家庭规则卡」，给 6 岁儿子展示两个选项。"
            "儿子表情从抵触变为若有所思，手指向了其中一个选项。"
            "爸爸微笑点头，氛围轻松有序，没有命令和眼泪。"
            "整体传递「给孩子选择权，行为自然改变」的正向引导画面。"
        ),
    },
    {
        "skill_id": "boundary_with_love",
        "skill_md_path": "skills/child_behavior/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国妈妈蹲下，双手温柔但坚定地扶住试图越界的孩子，眼神充满爱意又不动摇。"
            "孩子从挣扎到逐渐安定，感受到规则背后的安全感。"
            "暖黄灯光，家庭氛围温馨，整体传递「温柔而坚定的边界是孩子安全感的来源」。"
        ),
    },

    # ── child_emotion ─────────────────────────────────────────────────────────
    {
        "skill_id": "emotion_coaching",
        "skill_md_path": "skills/child_emotion/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国妈妈蹲下，静静地把正在大哭的孩子抱住，没有说「别哭了」，"
            "而是轻轻拍背，表情充满理解和温柔。"
            "孩子在被接纳的怀抱中情绪慢慢平复，呜咽声渐弱。"
            "整体传递「先接纳情绪，情感教练的核心」的治愈亲子时刻。"
        ),
    },
    {
        "skill_id": "emotion_naming",
        "skill_md_path": "skills/child_emotion/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国爸爸和 7 岁孩子坐在地板上，面前摆着一套情绪卡片（有不同表情图案）。"
            "爸爸指着「委屈」的卡片，孩子若有所思地点头，眼睛里有所悟。"
            "书桌旁阳光透入，氛围温暖轻松。整体传递「帮孩子为感受命名，情绪就失去了一半破坏力」。"
        ),
    },
    {
        "skill_id": "emotional_safety",
        "skill_md_path": "skills/child_emotion/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "夜晚，一位中国 8 岁孩子推开家门，跑向站在走廊等待的妈妈，妈妈张开双臂。"
            "温暖的室内灯光映照，孩子扑进妈妈怀里完全放松，表情从紧绷变为安心。"
            "整体传递「家是孩子情绪最安全的港湾，有安全感才敢探索世界」。"
        ),
    },

    # ── couple_decision ───────────────────────────────────────────────────────
    {
        "skill_id": "interest_based",
        "skill_md_path": "skills/couple_decision/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻坐在餐桌前，桌上有一张白纸，两人从各自写着「立场」（市区/大房子）"
            "的便利贴，移向一起研究底层原因，表情从对立变为专注和理解。"
            "氛围明亮平等，传递「从立场退到利益，才能找到真正的共识」。"
        ),
    },
    {
        "skill_id": "joint_process",
        "skill_md_path": "skills/couple_decision/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻各拿一支笔，共同在日历上标注「家庭决策日」，两人的笔指向同一天。"
            "表情专注而平等，桌上有咖啡和记事本，氛围从容有仪式感。"
            "整体传递「建立共同决策仪式，大事一起扛」的伴侣合作感。"
        ),
    },
    {
        "skill_id": "disagreement_navigate",
        "skill_md_path": "skills/couple_decision/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻本来背靠背坐着，其中一方缓缓转过身来伸出手，"
            "表情从倔强变为理解，另一方先是惊讶后慢慢接住这只手。"
            "月光透入窗户，整体传递「分歧是理解彼此的开始，伸手是和解的勇气」。"
        ),
    },

    # ── couple_finance ────────────────────────────────────────────────────────
    {
        "skill_id": "money_mindset",
        "skill_md_path": "skills/couple_finance/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻面前各有一个小储蓄罐，中间有一个更大的共同储蓄罐。"
            "两人同时将各自的小罐推向中间合并，表情从谨慎变为信任和微笑。"
            "温暖的家庭餐桌环境，整体传递「从各自的钱到我们的钱，金钱观融合之旅」。"
        ),
    },
    {
        "skill_id": "budget_together",
        "skill_md_path": "skills/couple_finance/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻坐在书桌前，共同看着一张月度家庭预算表，"
            "丈夫用笔指着某个项目提问，妻子认真解释，两人都在倾听，"
            "氛围平等合作，笔记本上记满了讨论要点。"
            "整体传递「共同制定预算，家庭财务的心往一处使」。"
        ),
    },
    {
        "skill_id": "financial_goals",
        "skill_md_path": "skills/couple_finance/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻站在一张手绘「家庭未来规划图」前，图上有房子、孩子、养老的图标。"
            "两人都在图上贴星形标签标注优先级，动作协调，表情充满对未来的期待感。"
            "整体传递「建立共同财务目标，朝同一方向用力的家庭方向感」。"
        ),
    },

    # ── couple_intimacy ───────────────────────────────────────────────────────
    {
        "skill_id": "love_language",
        "skill_md_path": "skills/couple_intimacy/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻在厨房，丈夫在做饭（行动服务），妻子走近说了一句话。"
            "丈夫停下来，第一次真正看着妻子，眼神里有理解和感动的光。"
            "妻子表情从委屈变为被看见后的温柔。整体传递「识别对方的爱的语言，爱才真正传达」。"
        ),
    },
    {
        "skill_id": "daily_connection",
        "skill_md_path": "skills/couple_intimacy/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻睡前各自把手机放在床头柜上，面对面侧躺着说话，"
            "笑容温柔，房间灯光暗淡温暖，两人专注地看着对方。"
            "整体传递「10 分钟无手机连接，抵住多少年的情感侵蚀」的日常亲密感。"
        ),
    },
    {
        "skill_id": "intimacy_restore",
        "skill_md_path": "skills/couple_intimacy/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻在公园散步，起初保持距离各看手机，"
            "慢慢一方将手机放入口袋，伸手牵住另一方，被牵者先是惊喜继而相视而笑。"
            "夕阳光线温暖，整体传递「从熟悉的陌生人重新找回恋人的感觉」。"
        ),
    },

    # ── elder_care ────────────────────────────────────────────────────────────
    {
        "skill_id": "care_agreement",
        "skill_md_path": "skills/elder_care/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "三位中国成年兄弟姐妹围坐在桌前，桌上有一张「家庭照护分工表」。"
            "三人共同讨论各自认领的任务，表情认真专注，没有推诿的姿态。"
            "整体传递「照护父母需要所有子女同向发力，公平分担」的家庭协作感。"
        ),
    },
    {
        "skill_id": "elder_dignity",
        "skill_md_path": "skills/elder_care/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国老人端坐椅子，成年子女蹲在老人面前仰视，"
            "不是替老人做决定而是问「您觉得怎么样？」，老人表情有尊严地思考后点头。"
            "整体传递「帮助不是控制，守护老人自主权才是真正的孝顺」。"
        ),
    },
    {
        "skill_id": "family_coordination",
        "skill_md_path": "skills/elder_care/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "中国家庭多名成员站成半圆，中间是坐着的老人，所有人朝向中心，"
            "一人拿着平板显示照护群组信息，大家神情和谐协调。"
            "整体传递「建立照护信息共享系统，让每个人都知道自己的角色」。"
        ),
    },

    # ── family_boundary ───────────────────────────────────────────────────────
    {
        "skill_id": "boundary_identify",
        "skill_md_path": "skills/family_boundary/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国年轻女性接到电话，内容让她皱眉停顿，若有所思地看着远方。"
            "她意识到某个边界被越过了，但没有立刻情绪化，而是在心里做了一个判断。"
            "整体传递「第一次清晰地意识到：这是干涉，不是关心」的内在觉察时刻。"
        ),
    },
    {
        "skill_id": "boundary_express",
        "skill_md_path": "skills/family_boundary/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国年轻人平静地面对父母，表情温柔但眼神坚定，"
            "说出「我理解你们的关心，但这个决定需要我自己来做」，"
            "父母从不解到停顿思考。整体传递「温和而坚定地表达边界，爱和独立可以同时存在」。"
        ),
    },
    {
        "skill_id": "freedom_and_love",
        "skill_md_path": "skills/family_boundary/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国年轻人站在家门口，一手回握父母伸来的手（连接），"
            "另一手自然指向自己生活的方向（独立），表情平和自信。"
            "整体传递「既爱家庭，又活出自己的人生——独立与连接不必二选一」。"
        ),
    },

    # ── family_conflict ───────────────────────────────────────────────────────
    {
        "skill_id": "de_escalation",
        "skill_md_path": "skills/family_conflict/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻正要争吵升级，其中一方举起双手做「暂停」手势，"
            "表情从愤怒快速切换为冷静，说「我们先冷静 20 分钟」。"
            "另一方先是惊讶后缓缓点头。整体传递「在冲突临界点踩刹车，阻止伤害的发生」。"
        ),
    },
    {
        "skill_id": "need_underneath",
        "skill_md_path": "skills/family_conflict/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻争吵后，其中一方表情软化，眼神变得脆弱，"
            "说出真正的感受「我只是需要你能听我说」，另一方从防御变为理解，微微靠近。"
            "整体传递「冲突背后是「我需要被看见」的深层需求」。"
        ),
    },
    {
        "skill_id": "repair_ritual",
        "skill_md_path": "skills/family_conflict/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "冷战后，一位中国男性端着一杯茶走向背对着他的妻子，"
            "妻子先是惊讶后慢慢接过茶，两人对视，眼中有和解的暖意。"
            "温暖灯光，整体传递「修复不是认输，是关系走向更深处的勇气」。"
        ),
    },

    # ── family_role ───────────────────────────────────────────────────────────
    {
        "skill_id": "role_expectation",
        "skill_md_path": "skills/family_role/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻各自写下对「好配偶」的期待清单，交换后互相阅读，"
            "表情从惊讶到理解，意识到彼此有不同的隐性标准。"
            "整体传递「第一次看见彼此从未说出口的期待——原来我们的标准从来不同」。"
        ),
    },
    {
        "skill_id": "role_negotiation",
        "skill_md_path": "skills/family_role/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻在白板前重新分配家庭角色任务清单，每项任务旁贴上姓名标签。"
            "两人共同讨论，表情平等认真，没有委屈没有强迫。"
            "整体传递「重新协商家庭角色分工——让每个人都不委屈」的合作感。"
        ),
    },
    {
        "skill_id": "role_flexibility",
        "skill_md_path": "skills/family_role/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "中国三口之家，妻子正在书房专注工作，丈夫在厨房愉快地做饭，孩子在旁边画画。"
            "三人各有其乐，氛围温馨和谐，没有固定性别角色的束缚。"
            "整体传递「好的家庭系统，是能柔性调整角色的弹性团队」。"
        ),
    },

    # ── household_division ────────────────────────────────────────────────────
    {
        "skill_id": "labor_visibility",
        "skill_md_path": "skills/household_division/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国女性拿着家务账本（密密麻麻列着家务条目），丈夫认真地看着，"
            "表情从漫不经心变为沉默的认真——「原来你做了这么多」。"
            "整体传递「让隐形劳动被看见，是公平协商的第一步」。"
        ),
    },
    {
        "skill_id": "fair_share",
        "skill_md_path": "skills/household_division/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻在白板前，白板上列着家务清单，每项旁边写上分工名字。"
            "两人共同讨论，指点清单，表情轻松平等，没有争吵。"
            "整体传递「事先说清楚谁负责什么，才能告别反复争吵」。"
        ),
    },
    {
        "skill_id": "sustainable_habit",
        "skill_md_path": "skills/household_division/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "中国家庭厨房冰箱上贴着彩色家务轮换表，夫妻两人各自按表做事，"
            "丈夫洗碗、妻子整理，氛围轻松有序，不需要提醒和催促。"
            "整体传递「把家务系统化而非靠记忆，建立可持续的分工习惯」。"
        ),
    },

    # ── inlaw_relationship ────────────────────────────────────────────────────
    {
        "skill_id": "triangle_dynamic",
        "skill_md_path": "skills/inlaw_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国丈夫站在婆婆和妻子中间，两边都在向他诉说，"
            "他若有所思地看向远方，意识到自己需要从「夹心饼干」升级为「协调者」。"
            "整体传递「婆媳冲突的核心是夫妻关系——丈夫的角色决定一切」。"
        ),
    },
    {
        "skill_id": "alliance_first",
        "skill_md_path": "skills/inlaw_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一对中国夫妻并肩站立，丈夫一手搂着妻子的肩，姿态坚定，"
            "背后是两家的父母，两人的目光方向一致，传递「我们是一队」的同盟感。"
            "整体传递「夫妻同盟优先，才能在三代关系中保持平衡」。"
        ),
    },
    {
        "skill_id": "generational_bridge",
        "skill_md_path": "skills/inlaw_relationship/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "中国婆婆和儿媳并排坐在沙发上，翻看一本家庭相册，"
            "婆婆指着某张照片微笑讲述，儿媳认真倾听，脸上有真实的兴趣和理解。"
            "整体传递「共同故事是跨代建立情感连接最有效的桥梁」。"
        ),
    },

    # ── study_pressure ────────────────────────────────────────────────────────
    {
        "skill_id": "expectation_gap",
        "skill_md_path": "skills/study_pressure/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "中国妈妈和孩子坐在桌前，桌上有一张试卷。"
            "妈妈不是皱眉看成绩，而是指着卷子上做对的题目，"
            "孩子眼中从紧张变为一丝轻松和希望。"
            "整体传递「先看见孩子做到了什么，期望才能成为动力而非压力」。"
        ),
    },
    {
        "skill_id": "pressure_convert",
        "skill_md_path": "skills/study_pressure/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国爸爸和孩子在餐桌上，爸爸分享一道有趣的思考题，"
            "孩子从一开始漫不经心到眼睛发亮，主动开始思考。"
            "整体传递「好奇心被点燃的瞬间——内在动力就是这样激活的」。"
        ),
    },
    {
        "skill_id": "support_presence",
        "skill_md_path": "skills/study_pressure/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国父亲在孩子书桌旁的另一张桌子上看书，"
            "不是盯着孩子，而是专注于自己的事，偶尔微笑递来一杯水。"
            "孩子在旁边安心学习，表情轻松专注。"
            "整体传递「陪伴而非监视，做孩子学业路上的加油站而非审判台」。"
        ),
    },

    # ── teen_communication ────────────────────────────────────────────────────
    {
        "skill_id": "teen_psychology",
        "skill_md_path": "skills/teen_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国 15 岁少年独自坐在房间里，手机放在一边，望着窗外，"
            "表情带着说不出的孤独和委屈，门外有父母的影子但不知道怎么进入他的世界。"
            "整体传递「叛逆背后是渴望被真正看见——理解才是沟通的起点」。"
        ),
    },
    {
        "skill_id": "trust_rebuild",
        "skill_md_path": "skills/teen_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国妈妈和 16 岁女儿并排坐在台阶上，夜色中只有路灯。"
            "妈妈先分享自己青春期的一个糗事，女儿从最初盯着手机到放下手机，"
            "侧过头开始倾听，表情慢慢打开。整体传递「先分享自己，孩子才肯开口」的信任重建。"
        ),
    },
    {
        "skill_id": "equal_dialogue",
        "skill_md_path": "skills/teen_communication/SKILL.md",
        "image_prompt": (
            ASIAN_TAG +
            "一位中国爸爸和 14 岁儿子面对面坐着，爸爸身体微微前倾，"
            "表情充满好奇地问「你怎么看这件事？」，儿子从防御变为思考，"
            "开始说话，爸爸认真倾听不打断。整体传递「放下权威，平等对话才有真正的影响力」。"
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
    pattern = rf'(  - id: {re.escape(skill_id)}\n(?:(?!  - id:)[\s\S])*?    cover_image:) ""'
    new_content = re.sub(pattern, rf'\1 "{image_url}"', content)
    if new_content == content:
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
        time.sleep(1)

    logger.info(f"\n{'='*50}\n汇总：")
    ok = sum(1 for v in results.values() if v)
    fail = sum(1 for v in results.values() if not v)
    for sid, url in results.items():
        logger.info(f"  {sid}: {'✅ ' + url if url else '❌ 失败'}")
    logger.info(f"\n成功: {ok} / 失败: {fail} / 总计: {len(results)}")


if __name__ == "__main__":
    main()
