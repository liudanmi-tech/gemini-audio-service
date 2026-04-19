"""
场景路由器 v2
- 场景分类输出 iOS 6 大分类（work_life / campus_life / relationships / family / personal_growth / life_skills）
- 手动模式：跳过场景分类，直接使用全部用户勾选技能
- 自动模式：LLM 单次调用完成场景分类 + 相关度打分，每场景取 top-5（高分优先）
- emotion_recognition 始终执行
"""
import os
import json
import copy
import logging
import uuid as _uuid_module
from typing import List, Dict, Optional, Tuple

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import google.generativeai as genai

from database.models import UserSkillPreference, CustomSkill
from .ios_skill_registry import (
    SYSTEM_SKILLS,
    CATEGORY_SCENE_DESCRIPTIONS,
    get_all_system_skill_ids,
    get_skills_by_category,
    get_skill_config,
)

logger = logging.getLogger(__name__)

GEMINI_FLASH_MODEL = os.getenv("GEMINI_FLASH_MODEL", "gemini-3-flash-preview")

# ────────────────────────────────────────────────────────
# 内部常量
# ────────────────────────────────────────────────────────
_ALWAYS_RUN_SKILL = "emotion_recognition"          # 始终运行，不参与用户选择
_DEPRESSION_SKILL = "depression_prevention"         # 条件触发，不在 iOS 技能库

_IOS_CATEGORIES = list(CATEGORY_SCENE_DESCRIPTIONS.keys())   # 排序固定

# 防抑郁触发词
_DEPRESSION_CRISIS_KW = ["不想活", "想活了", "活不下去", "死了算了", "想死", "自杀"]
_DEPRESSION_GENERAL_KW = [
    "搞砸", "没用", "失败", "我不配", "废物", "不行", "很差",
    "针对", "没意思", "不公平", "没办法", "讨厌", "都怪我",
    "完蛋", "没希望", "没救了", "不会好了",
    "总是", "绝对", "从来", "永远", "每次",
    "累", "烦", "焦虑", "抑郁", "崩溃", "压力大", "撑不住",
]

# 档案关系 → 强制 iOS 分类
_WORKPLACE_REL_TYPES = {
    "领导", "上级", "老板", "直属领导", "总监", "经理", "主管", "科长", "处长", "局长",
    "同事", "平级", "同级", "合作方", "客户", "甲方", "下属", "团队成员",
}
_FAMILY_REL_TYPES = {
    "老婆", "妻子", "老公", "丈夫", "爸爸", "父亲", "妈妈", "母亲",
    "儿子", "女儿", "孩子", "兄弟", "姐妹", "哥哥", "弟弟", "姐姐", "妹妹",
    "爷爷", "奶奶", "外公", "外婆", "祖父", "祖母", "家人",
}
_PROFILE_CATEGORY_MAP = {
    "work_life": _WORKPLACE_REL_TYPES,
    "family":    _FAMILY_REL_TYPES,
}

# ────────────────────────────────────────────────────────
# 方案A：无档案时的关键词兜底推断（按命中数投票）
# ────────────────────────────────────────────────────────
_KW_WORK_LIFE = [
    # 职称/称谓（高特异性）
    "老板", "领导", "上司", "总监", "经理", "主管", "老总", "总裁", "CEO",
    "同事", "下属", "同僚", "部门", "团队", "甲方", "乙方", "客户",
    "面试官", "HR", "猎头",
    # 职场场景词
    "开会", "汇报", "述职", "绩效", "KPI", "晋升", "加薪", "薪资", "工资",
    "项目", "需求", "排期", "deadline", "加班", "离职", "辞职", "裁员",
    "年终", "奖金", "职位", "岗位", "入职", "试用期",
]

_KW_FAMILY = [
    "老婆", "老公", "妻子", "丈夫", "媳妇", "爱人",
    "爸爸", "妈妈", "父亲", "母亲", "公公", "婆婆", "岳父", "岳母", "丈母娘",
    "儿子", "女儿", "孩子", "宝宝", "子女",
    "兄弟", "姐妹", "哥哥", "弟弟", "姐姐", "妹妹",
    "爷爷", "奶奶", "外公", "外婆",
]

_KW_CAMPUS = [
    "教授", "导师", "辅导员", "班主任",
    "室友", "舍友", "学长", "学姐", "学弟", "学妹",
    "宿舍", "寝室", "课题", "论文", "答辩", "毕业",
    "社团", "考研", "保研", "GPA", "挂科", "实习",
]

_KW_RELATIONSHIPS = [
    "男朋友", "女朋友", "男友", "女友", "对象", "相亲", "暗恋", "表白",
    "分手", "复合", "出轨", "劈腿", "约会", "恋爱",
    "闺蜜", "死党", "发小",
]

_KW_LIFE_SKILLS = [
    "房东", "房租", "物业", "邻居", "装修",
    "医生", "护士", "诊断", "就医", "挂号", "保险",
    "银行", "贷款", "理财", "还款", "信用卡",
    "客服", "投诉", "退款", "售后", "快递",
]

_KW_PERSONAL_GROWTH = [
    "自信", "自卑", "内耗", "边界感", "情绪管理",
    "拖延", "内向", "社恐", "迷茫", "方向感",
]

# (category, keywords, min_hits) — min_hits 防止低特异词误触发
_KW_CATEGORY_MAP = [
    ("work_life",       _KW_WORK_LIFE,       1),
    ("family",          _KW_FAMILY,          1),
    ("campus_life",     _KW_CAMPUS,          1),
    ("relationships",   _KW_RELATIONSHIPS,   1),
    ("life_skills",     _KW_LIFE_SKILLS,     1),
    ("personal_growth", _KW_PERSONAL_GROWTH, 2),  # 需 2+ 词命中，避免滥触发
]


# ────────────────────────────────────────────────────────
# 辅助：防抑郁触发检测
# ────────────────────────────────────────────────────────
def _should_trigger_depression(transcript: list) -> bool:
    user_text = "".join(
        item.get("text", item.get("content", ""))
        for item in transcript if item.get("is_me") is True
    )
    char_count = len(user_text.replace(" ", "").replace("\n", ""))
    for kw in _DEPRESSION_CRISIS_KW:
        if kw in user_text:
            logger.info(f"[抑郁监控] 危机词命中: 「{kw}」")
            return True
    if char_count >= 50:
        for kw in _DEPRESSION_GENERAL_KW:
            if kw in user_text:
                logger.info(f"[抑郁监控] 一般词命中: 「{kw}」 chars={char_count}")
                return True
    return False


# ────────────────────────────────────────────────────────
# 辅助：从用户偏好读取已选技能
# ────────────────────────────────────────────────────────
async def _get_user_selected_skills(user_id: str, db: AsyncSession) -> Tuple[bool, list[str]]:
    """
    返回 (is_manual_mode, selected_skill_ids)
    selected_skill_ids 包含系统子技能 ID 和 custom_uuid
    """
    try:
        uid = _uuid_module.UUID(user_id)
    except (ValueError, AttributeError):
        logger.warning(f"[用户偏好] 无效 user_id: {user_id}")
        return False, []

    rows = await db.execute(
        select(UserSkillPreference.skill_id, UserSkillPreference.selected).where(
            UserSkillPreference.user_id == uid,
        )
    )
    all_prefs = {r[0]: r[1] for r in rows.fetchall()}

    is_manual = all_prefs.get("__manual_mode__", False)
    selected_ids = [
        k for k, v in all_prefs.items()
        if v is True and k != "__manual_mode__"
    ]
    logger.info(f"[用户偏好] user={user_id} manual={is_manual} selected={len(selected_ids)} skills")
    return is_manual, selected_ids


# ────────────────────────────────────────────────────────
# 辅助：档案关系强制覆盖 iOS 分类
# ────────────────────────────────────────────────────────
def _forced_category_from_profiles(profiles: list[dict]) -> str | None:
    for p in profiles or []:
        rel = (p.get("relationship_type") or "").strip()
        for cat, rel_set in _PROFILE_CATEGORY_MAP.items():
            if rel in rel_set:
                logger.info(f"[档案强制] relationship_type={rel} → category={cat}")
                return cat
    return None


# ────────────────────────────────────────────────────────
# 方案A：无档案时从对话文本关键词推断 primary_category
# ────────────────────────────────────────────────────────
def _guess_category_from_transcript(transcript: list) -> str | None:
    """
    扫描全部对话文本，按关键词命中数投票推断 primary_category。
    命中数最多且满足最低门槛的分类获胜，未命中返回 None（交由 LLM 判断）。
    优先级：档案强制 > 关键词推断 > LLM 分类
    """
    all_text = "".join(
        item.get("text", item.get("content", ""))
        for item in transcript
    )
    if not all_text.strip():
        return None

    hit_counts: dict[str, int] = {}
    for category, keywords, min_hits in _KW_CATEGORY_MAP:
        count = sum(1 for kw in keywords if kw in all_text)
        if count >= min_hits:
            hit_counts[category] = count
            logger.debug(f"[关键词] {category}: {count} 词命中")

    if not hit_counts:
        logger.info("[关键词预处理] 无分类命中，交由 LLM 判断")
        return None

    best = max(hit_counts, key=hit_counts.get)
    logger.info(f"[关键词预处理] 命中分类={best} ({hit_counts[best]} 词)，完整计数={hit_counts}")
    return best


# ────────────────────────────────────────────────────────
# 核心：LLM 场景分类 + 相关度打分（自动模式，单次调用）
# ────────────────────────────────────────────────────────
def classify_and_score(
    transcript: list,
    selected_skill_ids: list[str],
    model=None,
) -> dict:
    """
    单次 LLM 调用完成：
      1. 场景分类 → iOS 6 大分类
      2. 对 selected_skill_ids 中每个技能打相关度分 0-100

    Returns:
        {
            "primary_category": "work_life",
            "scene_description": "...",
            "skill_scores": {"salary_negotiation": 91, ...}
        }
    """
    if model is None:
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)

    # 构建技能描述列表（给 LLM 看的）
    skill_desc_lines = []
    for sid in selected_skill_ids:
        cfg = get_skill_config(sid)
        if cfg:
            name = cfg["name"]
            focus = cfg.get("exec_context", {}).get("focus", "")
            skill_desc_lines.append(f'  "{sid}": "{name} — {focus}"')
        else:
            skill_desc_lines.append(f'  "{sid}": "{sid}"')
    skill_desc_block = "\n".join(skill_desc_lines)

    category_desc_lines = "\n".join(
        f'  "{k}": "{v}"' for k, v in CATEGORY_SCENE_DESCRIPTIONS.items()
    )

    prompt = f"""You are an expert conversation analyst specializing in interpersonal dynamics.
Analyze the transcript carefully using the three steps below.

---
## Step 0: Identify the Other Person
Who is Speaker B (the person the user is talking WITH)?
Pick ONE that best fits:
- boss_or_superior (manager, director, CEO, client with authority over user)
- coworker_or_peer (colleague at same level, teammate, business partner)
- subordinate (someone user manages or mentors)
- romantic_partner (boyfriend, girlfriend, spouse, ex)
- parent_or_inlaw (mom, dad, mother-in-law, father-in-law)
- child_or_teen (user's child, teenage child)
- other_family (sibling, grandparent, extended family)
- professor_or_teacher (professor, advisor, teacher, school supervisor)
- classmate_or_roommate (fellow student, dormmate, study group member)
- close_friend (best friend, old friend, confidant)
- stranger_or_service (customer service, doctor, landlord, neighbor, bank)
- self_reflection (user is talking to themselves / journaling / no clear other person)
- unknown

---
## Step 1: Scene Classification
Based on who Speaker B is, select the PRIMARY category:

- "work_life": Speaker B is a boss, coworker, client, HR, or job interviewer. Topics: salary, performance, deadlines, workplace politics, job search, promotions.
  → Use this even if topic feels personal but the other person has a professional role.

- "campus_life": Speaker B is a professor, advisor, classmate, or roommate. Topics: grades, thesis, group projects, dorm life, internship offers, campus social.

- "relationships": Speaker B is a romantic partner, ex, or close friend. Topics: dating, breakups, friendship conflicts, coming out, emotional support between friends.
  → Do NOT use for family members — use "family" instead.

- "family": Speaker B is a parent, spouse, child, sibling, or extended family. Topics: parenting, family decisions, money within family, generational conflict, co-parenting.
  → Use this even if the relationship feels tense or hostile.

- "personal_growth": No clear Speaker B, or user is reflecting inward. Topics: anxiety, self-doubt, procrastination, anger management, assertiveness, inner critic.
  → Only use if conversation is primarily about user's internal state, NOT an interpersonal conflict with a specific person.

- "life_skills": Speaker B is a landlord, doctor, customer service rep, neighbor, or bank. Topics: healthcare navigation, contracts, housing disputes, consumer complaints, financial decisions.

Disambiguation rules (apply in order):
1. If Speaker B has a job title or workplace authority → "work_life" (even if topic sounds personal)
2. If Speaker B is a spouse, parent, or child → "family" (not "relationships")
3. If user vents about work/family TO a friend → "relationships"
4. Ambiguous between work_life and personal_growth → prefer "work_life"
5. Ambiguous between family and relationships → prefer "family"

---
## Step 2: Skill Relevance Scoring
Score each skill's relevance to THIS specific conversation (0–100):

{{{skill_desc_block}}}

Scoring guide:
- 80–100: Highly relevant — directly addresses what's happening, user would benefit immediately
- 50–79:  Somewhat relevant — useful context but not the core issue
- 0–49:   Tangential or not helpful for this conversation

Score each skill independently. Spread scores out — avoid clustering everything at 50.
Include ALL skill IDs in your response.

---
Return ONLY valid JSON, no extra text:
{{
  "other_person_type": "<one of the Step 0 options>",
  "primary_category": "<one of the 6 category keys>",
  "scene_description": "<1-2 sentences: what is happening and what does the user need help with>",
  "skill_scores": {{
    "<skill_id>": <0-100>,
    ...
  }}
}}

Conversation transcript:
{json.dumps(transcript, ensure_ascii=False, indent=2)}"""

    try:
        logger.info("[场景分类+打分] 开始 LLM 调用")
        response = model.generate_content(prompt)
        raw = response.text.strip()
        logger.info(f"[场景分类+打分] 响应长度={len(raw)}")

        import re
        parsed = None
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            m = re.search(r'```(?:json)?\s*\n?(.*?)\n?```', raw, re.DOTALL)
            if m:
                try:
                    parsed = json.loads(m.group(1).strip())
                except json.JSONDecodeError:
                    pass
        if parsed is None:
            m2 = re.search(r'\{.*\}', raw, re.DOTALL)
            if m2:
                try:
                    parsed = json.loads(m2.group(0))
                except json.JSONDecodeError:
                    pass

        if not parsed:
            raise ValueError(f"无法解析 JSON: {raw[:200]}")

        primary = parsed.get("primary_category", "work_life")
        if primary not in _IOS_CATEGORIES:
            primary = "work_life"
            logger.warning(f"[场景分类] 非法 primary_category，兜底 work_life")

        scores = parsed.get("skill_scores", {})
        # 确保所有技能都有分数，缺失的补 50
        for sid in selected_skill_ids:
            if sid not in scores:
                scores[sid] = 50

        other_person_type = parsed.get("other_person_type", "unknown")
        result = {
            "primary_category": primary,
            "scene_description": parsed.get("scene_description", ""),
            "skill_scores": scores,
            "other_person_type": other_person_type,
        }
        logger.info(f"[场景分类] primary_category={primary} other_person={other_person_type}")
        logger.info(f"[场景分类] scene_description={result['scene_description'][:100]}")
        return result

    except Exception as e:
        logger.error(f"[场景分类+打分] 失败: {e}", exc_info=True)
        # 兜底：primary 用第一个 selected skill 的 category，全部给 50 分
        fallback_cat = "work_life"
        if selected_skill_ids:
            cfg = get_skill_config(selected_skill_ids[0])
            if cfg:
                fallback_cat = cfg.get("category", "work_life")
        return {
            "primary_category": fallback_cat,
            "scene_description": "",
            "skill_scores": {sid: 50 for sid in selected_skill_ids},
        }


# ────────────────────────────────────────────────────────
# 核心：构建 skill_card 列表（不执行内容，只决定哪些技能上场）
# ────────────────────────────────────────────────────────
async def match_skills_v2(
    transcript: list,
    profiles: list[dict] | None,
    user_id: str | None,
    db: AsyncSession,
    model=None,
) -> list[dict]:
    """
    返回 skill_card stub 列表（content=None），供 main.py 决定执行顺序。

    每个 stub 结构：
    {
        "skill_id":      "salary_negotiation",   # 统一 iOS ID / custom_uuid
        "skill_name":    "Salary Negotiation",
        "category":      "work_life",             # iOS 分类
        "score":         91,                      # 相关度，手动模式 None
        "is_custom":     False,
        "exec_template": "_exec_work_life",
        "exec_context":  {...},
        "execute_now":   True/False,              # True = 立即执行
        "content_type":  "pending",
        "content":       None,
    }
    emotion_recognition 单独以 always_run=True 标记。
    """
    # 1. 读用户偏好
    is_manual, selected_ids = (False, []) if not user_id else \
        await _get_user_selected_skills(user_id, db)

    # 如果没有任何偏好：用全部 43 个系统技能（新用户兜底）
    if not selected_ids:
        selected_ids = get_all_system_skill_ids()
        logger.info("[技能匹配] 无用户偏好，使用全部 43 个系统技能")

    # 档案关系强制覆盖分类
    forced_cat = _forced_category_from_profiles(profiles or [])

    # 方案A：无档案时，关键词兜底推断分类（优先级：档案 > 关键词 > LLM）
    if forced_cat is None:
        forced_cat = _guess_category_from_transcript(transcript)

    # ── 手动模式 ─────────────────────────────────────────
    if is_manual:
        logger.info(f"[技能匹配] 手动模式：直接使用 {len(selected_ids)} 个用户选中技能")
        stubs = _build_stubs_manual(selected_ids)
        stubs = _append_always_run(stubs, transcript)
        return stubs

    # ── 自动模式 ─────────────────────────────────────────
    logger.info(
        f"[技能匹配] 自动模式：场景分类 + 打分，selected={len(selected_ids)}，"
        f"forced_cat={forced_cat}（档案/关键词）"
    )
    scene_result = classify_and_score(transcript, selected_ids, model=model)

    primary_cat = forced_cat or scene_result["primary_category"]
    scores      = scene_result["skill_scores"]
    logger.info(
        f"[技能匹配] primary_cat={primary_cat}"
        f"（来源={'forced' if forced_cat else 'LLM'}），"
        f"LLM分类={scene_result['primary_category']}，"
        f"对方身份={scene_result.get('other_person_type', 'unknown')}"
    )

    stubs = _build_stubs_auto(selected_ids, scores, primary_cat)
    stubs = _append_always_run(stubs, transcript)
    return stubs


# ────────────────────────────────────────────────────────
# 手动模式：所有选中技能按分类分组，每组第一个 execute_now=True
# ────────────────────────────────────────────────────────
def _build_stubs_manual(selected_ids: list[str]) -> list[dict]:
    # 按 iOS 分类分组
    groups: dict[str, list[str]] = {cat: [] for cat in _IOS_CATEGORIES}
    groups["custom"] = []

    for sid in selected_ids:
        cfg = get_skill_config(sid)
        cat = cfg["category"] if cfg else "custom"
        groups.setdefault(cat, []).append(sid)

    stubs = []
    for cat in _IOS_CATEGORIES + ["custom"]:
        cat_skills = groups.get(cat, [])
        for idx, sid in enumerate(cat_skills):
            cfg = get_skill_config(sid) or {}
            stubs.append({
                "skill_id":      sid,
                "skill_name":    cfg.get("name", sid),
                "category":      cat,
                "score":         None,           # 手动模式无分数
                "is_custom":     sid.startswith("custom_"),
                "exec_template": cfg.get("exec_template", "_exec_work_life"),
                "exec_context":  cfg.get("exec_context", {}),
                "execute_now":   (idx == 0),     # 每组第一个立即执行
                "content_type":  "pending",
                "content":       None,
            })
    logger.info(f"[手动模式] 构建 {len(stubs)} 个 stub")
    return stubs


# ────────────────────────────────────────────────────────
# 自动模式：按分数降序，每个命中场景取 top-5
# ────────────────────────────────────────────────────────
def _build_stubs_auto(
    selected_ids: list[str],
    scores: dict[str, int | float],
    primary_category: str,
) -> list[dict]:
    """
    自动模式 stub 构建（含场景过滤 + 子技能阈值）：
      - 场景过滤：每个场景的代表分（该场景下最高子技能分）占所有场景总分的比例 < 5% → 剔除
      - 场景上限：最多保留 3 个场景，primary_category 强制保留并置顶
      - 子技能阈值：分数 < 90 的子技能不展示
      - 子技能上限：每个场景最多展示 3 条子技能
      - 兜底：若 primary_category 内无 90+ 技能，降级展示该场景最高分 1 条
    """
    _SCENE_PCT_THRESHOLD  = 0.05   # 场景占比门槛（5%）
    _MAX_SCENES           = 3      # 最多场景数
    _SKILL_SCORE_MIN      = 90     # 子技能最低展示分
    _MAX_SKILLS_PER_SCENE = 3      # 每场景最多子技能数

    # ── Step 1: 按 iOS 分类分组 ──────────────────────────────
    groups: dict[str, list[tuple]] = {}  # cat → [(score, sid)]
    for sid in selected_ids:
        cfg = get_skill_config(sid)
        cat = cfg["category"] if cfg else "custom"
        score = float(scores.get(sid, 0))
        groups.setdefault(cat, []).append((score, sid))

    # ── Step 2: 计算每个场景的代表分（该场景下最高子技能分）────
    cat_rep: dict[str, float] = {
        cat: max((s for s, _ in slist), default=0.0)
        for cat, slist in groups.items()
        if slist
    }

    # ── Step 3: 场景过滤：占比 < 5% 的场景剔除 ──────────────
    total_rep = sum(cat_rep.values()) or 1.0
    valid_cats: dict[str, float] = {
        cat: rep
        for cat, rep in cat_rep.items()
        if rep / total_rep >= _SCENE_PCT_THRESHOLD
    }

    # primary_category 强制保留（档案/关键词命中的场景不因低分被丢弃）
    if primary_category not in valid_cats and primary_category in cat_rep:
        valid_cats[primary_category] = cat_rep[primary_category]
        logger.info(
            f"[场景过滤] {primary_category} 占比="
            f"{cat_rep[primary_category]/total_rep:.1%} < 5%，但为 primary，强制保留"
        )

    # ── Step 4: 按代表分降序，primary_category 置顶，最多 3 个场景 ──
    sorted_cats = sorted(
        valid_cats.keys(),
        key=lambda c: (c != primary_category, -valid_cats[c])
    )[:_MAX_SCENES]

    logger.info(
        f"[场景过滤] 原始场景={list(cat_rep.keys())}，"
        f"过滤后保留={sorted_cats}（占比门槛={_SCENE_PCT_THRESHOLD:.0%}）"
    )

    # ── Step 5: 构建 stubs ──────────────────────────────────
    stubs = []
    for cat in sorted_cats:
        raw_skills = groups.get(cat, [])

        # 只取分数 >= 90 的子技能，按分数降序，最多 3 条
        qualified = sorted(
            [(s, sid) for s, sid in raw_skills if s >= _SKILL_SCORE_MIN],
            key=lambda x: x[0], reverse=True
        )[:_MAX_SKILLS_PER_SCENE]

        # 兜底：primary_category 无 90+ 技能时，展示最高分 1 条（保证有内容）
        if not qualified and cat == primary_category:
            fallback = sorted(raw_skills, key=lambda x: x[0], reverse=True)[:1]
            qualified = fallback
            if qualified:
                logger.info(
                    f"[场景过滤] {cat} 无 {_SKILL_SCORE_MIN}+ 技能，"
                    f"兜底展示最高分技能 score={int(qualified[0][0])}"
                )

        if not qualified:
            logger.info(f"[场景过滤] {cat} 无满足条件的子技能，跳过")
            continue

        for idx, (score, sid) in enumerate(qualified):
            cfg = get_skill_config(sid) or {}
            stubs.append({
                "skill_id":      sid,
                "skill_name":    cfg.get("name", sid),
                "category":      cat,
                "score":         int(score),
                "is_custom":     sid.startswith("custom_"),
                "exec_template": cfg.get("exec_template", "_exec_work_life"),
                "exec_context":  cfg.get("exec_context", {}),
                "execute_now":   (idx == 0),   # 每场景第一个立即执行
                "content_type":  "pending",
                "content":       None,
            })

    logger.info(
        f"[自动模式] 构建 {len(stubs)} 个 stub（"
        f"primary={primary_category}，场景数={len(sorted_cats)}，"
        f"子技能门槛={_SKILL_SCORE_MIN}分）"
    )
    for s in stubs:
        logger.info(f"  {s['category']}  {s['skill_id']}  score={s['score']}  exec_now={s['execute_now']}")
    return stubs


# ────────────────────────────────────────────────────────
# 追加始终运行技能（情绪识别 + 条件性抑郁监控）
# ────────────────────────────────────────────────────────
def _append_always_run(stubs: list[dict], transcript: list) -> list[dict]:
    # emotion_recognition 置顶（排在列表最前面）
    emotion_stub = {
        "skill_id":      _ALWAYS_RUN_SKILL,
        "skill_name":    "Emotion Check",
        "category":      "always",
        "score":         None,
        "is_custom":     False,
        "exec_template": "_exec_emotion",
        "exec_context":  {},
        "execute_now":   True,
        "content_type":  "emotion",
        "content":       None,
        "always_run":    True,
    }

    result = [emotion_stub] + stubs

    # depression_prevention（条件触发，追加到末尾）
    if _should_trigger_depression(transcript):
        dep_stub = {
            "skill_id":      _DEPRESSION_SKILL,
            "skill_name":    "Mental Health Check",
            "category":      "always",
            "score":         None,
            "is_custom":     False,
            "exec_template": "_exec_depression",
            "exec_context":  {},
            "execute_now":   True,
            "content_type":  "mental_health",
            "content":       None,
            "always_run":    True,
        }
        result.append(dep_stub)

    return result


# ────────────────────────────────────────────────────────
# 向后兼容：保留旧版 classify_scene / match_skills 函数签名
# 供 main.py 旧路径调用（过渡期，逐步迁移）
# ────────────────────────────────────────────────────────
def classify_scene(transcript: list, model=None) -> dict:
    """旧接口兼容层：只做场景分类，不打分"""
    # 无需打分时直接走 LLM 分类
    if model is None:
        model = genai.GenerativeModel(GEMINI_FLASH_MODEL)
    result = classify_and_score(transcript, [], model=model)
    return {
        "primary_scene": result["primary_category"],
        "scenes": [{"category": result["primary_category"], "confidence": 0.9}],
        "workplace_dimensions": [],
        "_ios_scene": result,
    }


async def match_skills(
    scene_result: dict,
    db: AsyncSession,
    transcript: list = None,
    profiles: list[dict] | None = None,
    user_id: str | None = None,
    model=None,
) -> list[dict]:
    """旧接口兼容层：转发到 match_skills_v2"""
    return await match_skills_v2(
        transcript=transcript or [],
        profiles=profiles,
        user_id=user_id,
        db=db,
        model=model,
    )
