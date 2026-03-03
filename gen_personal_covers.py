#!/usr/bin/env python3
"""
个人技能封面图生成脚本（36张）
- 覆盖：anger_regulation(3) / anxiety_management(3) / burnout_recovery(3)
         grief_processing(3) / growth_mindset(3) / inner_critic(3)
         life_meaning(3) / procrastination(3) / resilience_build(3)
         self_worth(3) / stress_management(3) / values_clarity(3)
- 风格：皮克斯 3D，东亚人物面孔
"""

import os, sys, re, time, logging
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("gen_personal")

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
ASIAN_TAG = "East Asian face, Chinese person, "

SKILLS = [
    # anger_regulation
    ("anger_trigger", "skills/anger_regulation/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm red tones. A Chinese man sits alone at a desk, eyes closed, hands pressed to his temples. Behind him, a ghostly silhouette of an old memory — a stern father figure gesturing. The man's expression shows dawning recognition, not rage but understanding. Soft warm light. Message: anger has a root. Pixar 3D, rich textures."),
    ("anger_pause", "skills/anger_regulation/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm amber tones. A Chinese woman stands in a kitchen, water glass in her hand, mid-pour. Her eyes are closed, shoulders relaxing visibly. Behind her through the doorway, a child at the homework table. The woman's expression shifts from tense to calm — a visible 6-second pause. Message: pause creates space. Pixar 3D."),
    ("anger_channel", "skills/anger_regulation/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm peachy tones. A Chinese couple facing each other, both standing. The man's hand is open (not pointing), his expression vulnerable rather than aggressive. The woman listens, slightly leaning in. Between them, small glowing symbols of a heart and a speech bubble — emotions being translated into words. Message: anger becomes communication. Pixar 3D."),
    # anxiety_management
    ("worry_audit", "skills/anxiety_management/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, cool blue tones. A Chinese woman at a desk with a large sheet of paper divided into two columns: '可控 (Controllable)' and '不可控 (Uncontrollable)'. She is moving worry-bubbles (illustrated as cloud shapes) from one column to the other with focused calm. 85% of clouds move to the 'uncontrollable' side. Message: most worries are uncontrollable. Pixar 3D."),
    ("rumination_break", "skills/anxiety_management/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, soft blue-white tones. A Chinese man sitting in mindfulness pose. Around his head, thought-bubble clouds loop in circles. He observes them with gentle distance — not grabbing them, not fighting them. One hand raised slightly as if watching clouds drift by. Expression: peaceful observer, not victim of thoughts. Message: thoughts are not facts. Pixar 3D."),
    ("grounding_skills", "skills/anxiety_management/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, soft sky-blue tones. A Chinese woman standing outdoors, bare feet firmly on green grass, eyes closed. Her hands are spread slightly, face tilted upward with eyes closed. Five sensory icons float around her gently: eye, hand, ear, nose, mouth. Expression: grounded, present, safe. Message: the body is the anchor. Pixar 3D."),
    # burnout_recovery
    ("burnout_diagnosis", "skills/burnout_recovery/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, muted orange tones. A Chinese man in office clothes sitting across from a kind counselor. The counselor holds a clipboard with a burnout meter (three gauges: emotional exhaustion, cynicism, effectiveness). The man looks at the meter with recognition — finally seeing what's happening to him. Expression: relief of being understood. Message: naming it is the first step. Pixar 3D."),
    ("meaning_restore", "skills/burnout_recovery/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm amber-orange tones. A Chinese woman at work desk, but instead of the usual dull expression, she holds a glowing orb — representing a meaningful memory of helping someone. On her wall, a small thank-you note is highlighted. Her expression: quiet joy rediscovered. Message: meaning is not in the job title. Pixar 3D."),
    ("recovery_rhythm", "skills/burnout_recovery/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm golden tones. A Chinese man outdoors on a weekend — phone deliberately left on a table face-down behind him (visible), he is actively hiking in green nature with a relaxed smile. Small calendar on the wall shows checked recovery days. Expression: free, recharged. Message: recovery is a system, not a luxury. Pixar 3D."),
    # grief_processing
    ("grief_allow", "skills/grief_processing/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, soft silver-grey tones. A Chinese woman sitting in a quiet room, finally allowing herself to cry — tissues nearby, shoulders released, face open in grief. A warm gentle light illuminates her, suggesting safety. Around her, soft subtle flower petals fall slowly. Expression: not broken, but releasing. Message: tears are healing, not weakness. Pixar 3D."),
    ("grief_stages", "skills/grief_processing/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, misty grey-blue tones. A Chinese man walking a winding path through fog — the path curves back and forward, symbolizing grief's non-linear nature. Sometimes he looks back, sometimes forward, sometimes sits down. Expression: acceptance of the meandering journey. Message: grief is not linear. Pixar 3D."),
    ("meaning_rebuild", "skills/grief_processing/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, soft warm silver tones. A Chinese woman carefully placing a small photo frame and a teacup on a clean shelf — kept items from a loved one, surrounded by space and light. Her expression: bittersweet peace, honoring while continuing. Message: love carries forward. Pixar 3D."),
    # growth_mindset
    ("fixed_detect", "skills/growth_mindset/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, fresh green tones. A Chinese man looking at a thought bubble above his head showing '我就是不行' (I am just not capable). He observes it with mild surprise — noticing it for the first time rather than believing it. A small magnifying glass in his hand examining the thought. Expression: curious discovery. Message: noticing is the start of change. Pixar 3D."),
    ("failure_reframe", "skills/growth_mindset/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, bright green-gold tones. A Chinese woman looking at a failed presentation chart on screen, but instead of dejected, she holds a notebook open with the words '学到了什么?' (What did I learn?). Small data icons transform from red X marks to green checkmarks representing lessons. Expression: calm curiosity, not shame. Message: failure is data. Pixar 3D."),
    ("challenge_embrace", "skills/growth_mindset/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, vibrant green tones. A Chinese man standing at the edge of a stepping stone path that extends into the unknown, each step slightly higher than the last. He steps forward with a small smile — nervous but choosing. A glowing zone around the next step labeled '成长区' (Growth Zone). Expression: courageous choice. Message: growth lives at the edge of comfort. Pixar 3D."),
    # inner_critic
    ("critic_voice", "skills/inner_critic/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, soft purple tones. A Chinese woman looking in a mirror. Behind her, a small shadowy critical figure (representing inner critic) whispers in her ear. But she turns to look at it directly with calm curiosity — not frightened, but recognizing it. Expression: recognition without fear. Message: the inner critic loses power when seen. Pixar 3D."),
    ("self_compassion", "skills/inner_critic/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm lavender tones. A Chinese man sitting with hands on heart, eyes closed, a gentle warm glow radiating from his chest. Beside him, a small version of himself (representing a struggling friend) — he is offering the same kindness to himself he would offer a friend. Expression: tender self-acceptance. Message: treat yourself like a dear friend. Pixar 3D."),
    ("inner_ally", "skills/inner_critic/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, soft purple-white tones. A Chinese woman with a wise, warm presence beside her — an inner ally figure (like a kind elder or mentor, glowing softly). They face challenges together. The woman's expression: supported, not alone. The ally looks at her with deep trust. Message: you can be your own ally. Pixar 3D."),
    # life_meaning
    ("meaning_audit", "skills/life_meaning/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, indigo-purple tones. A Chinese man at a desk with a large life diagram — three circles labeled '工作意义' (Work meaning), '关系意义' (Relationship meaning), '超越意义' (Transcendent meaning). Some circles glowing brightly, others dim. He maps where meaning is missing. Expression: honest self-examination, not despair. Message: diagnose before treating. Pixar 3D."),
    ("ikigai_explore", "skills/life_meaning/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, deep indigo tones. A Chinese woman at the center of four overlapping circles floating around her: '热爱' (Love), '擅长' (Skill), '世界需要' (World needs), '能维持' (Livelihood). At the intersection where all four meet, a warm golden glow. Her expression: wonder and discovery. Message: ikigai is where they all meet. Pixar 3D."),
    ("existential_ground", "skills/life_meaning/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, deep blue-purple night sky tones. A Chinese man standing on solid ground under a vast starry sky. Despite the enormity of the universe, he stands firmly — one hand touching his heart, expression of quiet resolve. A small lantern in his hand. Message: even in the void, you can choose to stand. Pixar 3D."),
    # procrastination
    ("procrastin_root", "skills/procrastination/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, fresh lime-green tones. A Chinese man sitting at a desk with his laptop open but looking away. A thought bubble reveals not laziness but a small figure hiding behind a wall — representing fear of failure. His expression: the moment of realizing it's not laziness, it's fear. Message: procrastination is an emotion. Pixar 3D."),
    ("action_trigger", "skills/procrastination/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, bright yellow-green tones. A Chinese woman returning home, eyes immediately falling on her running shoes placed by the door (visible, deliberate placement). She is already reaching for them. Expression: automatic, effortless action triggered by environment. Message: design your environment, skip the willpower. Pixar 3D."),
    ("momentum_build", "skills/procrastination/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, energetic green tones. A Chinese man looking at a calendar on the wall with a streak of green circles marked consecutively. His expression: pride and protective energy — not wanting to break the chain. On his desk, a small notebook open to a running word count. Message: progress creates momentum. Pixar 3D."),
    # resilience_build
    ("setback_decode", "skills/resilience_build/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, teal-green tones. A Chinese man holding a document labeled '失业通知' (Layoff Notice), but instead of devastated, he sits at a table rewriting his interpretation: '公司战略调整 → 可调整方向' (Strategy change → direction to adjust). Expression: translator of adversity, not victim. Message: reinterpretation changes everything. Pixar 3D."),
    ("bounce_back", "skills/resilience_build/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, vibrant emerald green tones. A Chinese woman who has fallen down — but caught mid-rise, with determination on her face. Around her, supportive figures (friends/family) helping lift. Expression: not unaffected, but rising. Message: resilience includes asking for help. Pixar 3D."),
    ("post_traumatic_growth", "skills/resilience_build/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, luminous green-gold tones. A Chinese man looking at a small scar on his arm with gentle pride, not shame. Behind him, an impression of a difficult past (shadowy), but he stands in bright light — stronger, wiser. A small tree growing from rocky ground beside him. Expression: earned strength, not denial of pain. Message: wounds become wisdom. Pixar 3D."),
    # self_worth
    ("worth_source", "skills/self_worth/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm pink tones. A Chinese woman drawing a pie chart: 90% labeled '职业成就' (Career success), tiny sliver labeled '仅仅存在' (Just being). She stares at it with quiet recognition — this imbalance is visible, real. Expression: the moment of honest seeing. Message: worth built on one thing is fragile. Pixar 3D."),
    ("imposter_syndrome", "skills/self_worth/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, rosy-pink tones. A Chinese man in a meeting room, looking at his achievement list. Around him, small doubt-ghosts whisper '只是运气' (Just luck), '会被发现' (Will be exposed). But his pen is moving — writing down evidence of real competence. Expression: defiant, evidence-based self-recognition. Message: the evidence is real. Pixar 3D."),
    ("inner_stability", "skills/self_worth/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, soft pink-white tones. A Chinese woman standing in a gentle storm — wind swirling, but she stands steady, rooted. Her inner light glows from within, unchanging despite the external chaos. Expression: unshakeable inner ground. A small tree with deep roots beside her. Message: the storm outside cannot uproot what is inside. Pixar 3D."),
    # stress_management
    ("stress_audit", "skills/stress_management/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, cool indigo-blue tones. A Chinese man with a large mind-map on a board, color-coded: red (high stress), orange (medium), green (low). He circles the true high-stress sources — fewer than he thought. Expression: clarity and relief. Message: stress is manageable when located. Pixar 3D."),
    ("response_map", "skills/stress_management/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, purple-blue tones. A Chinese woman observing a diagram of her stress responses: fight (red), flight (yellow), freeze (grey). She points to 'freeze' with recognition — 'this is me'. Expression: compassionate self-knowledge, not judgment. Message: knowing your pattern is the start of changing it. Pixar 3D."),
    ("buffer_system", "skills/stress_management/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, calming indigo tones. A Chinese man with a layered toolkit wall: labeled '1分钟' (1 min), '15分钟' (15 min), '1小时' (1 hour), '半天' (half day). Each layer shows a different calming activity. He selects one with calm confidence. Expression: equipped, not overwhelmed. Message: a system beats willpower. Pixar 3D."),
    # values_clarity
    ("values_uncover", "skills/values_clarity/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm golden tones. A Chinese woman at a desk with 100 handwritten notes spread out before her. One note glows brighter than the rest: '让某人的生活变好' (Make someone's life better). She picks it up with dawning recognition. Expression: surprised discovery of her true self. Message: your real values are hiding in the 70th answer. Pixar 3D."),
    ("conflict_resolve", "skills/values_clarity/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm amber tones. A Chinese man holding two glowing orbs — one labeled '家庭稳定' (Family stability), one labeled '职业成长' (Career growth). They gently pull against each other, but his expression is thoughtful rather than torn — he holds both with care. A third space between them begins to glow: the creative solution. Message: hold both, find the third way. Pixar 3D."),
    ("compass_build", "skills/values_clarity/SKILL.md",
     ASIAN_TAG + "Pixar 3D style, warm golden-white tones. A Chinese woman holding a small glowing compass — but instead of N/S/E/W, it shows her three core values in radiant text. When facing a fork in the road, the compass points clearly. Expression: anchored certainty. Message: know your values, find your direction. Pixar 3D."),
]

def generate_image(prompt: str, skill_id: str, max_retries: int = 3):
    model = genai.GenerativeModel(IMAGE_GEN_MODEL)
    for attempt in range(1, max_retries + 1):
        try:
            logger.info(f"[{skill_id}] 生成中... (attempt {attempt})")
            t0 = time.time()
            resp = model.generate_content(
                [{"role": "user", "parts": [{"text": prompt}]}],
                generation_config={"response_modalities": ["IMAGE", "TEXT"]},
            )
            elapsed = time.time() - t0
            logger.info(f"[{skill_id}] 耗时 {elapsed:.1f}s")
            for part in resp.candidates[0].content.parts:
                if hasattr(part, "inline_data") and part.inline_data and part.inline_data.data:
                    data = part.inline_data.data
                    if isinstance(data, str):
                        import base64; data = base64.b64decode(data)
                    if len(data) > 1000:
                        logger.info(f"[{skill_id}] ✅ {len(data):,} bytes")
                        return data
            logger.warning(f"[{skill_id}] ⚠️ 无图片数据")
        except Exception as e:
            logger.error(f"[{skill_id}] 异常 (attempt {attempt}): {e}")
        if attempt < max_retries:
            time.sleep(3)
    return None

def upload_oss(data: bytes, skill_id: str) -> str | None:
    """保存到本地/tmp，scp 到北京服务器，在服务器上运行 oss_upload.py 上传"""
    import subprocess
    tmp_path = f"/tmp/{skill_id}_pixar.png"
    with open(tmp_path, "wb") as f:
        f.write(data)
    # scp 到服务器
    r = subprocess.run(
        ["sshpass", "-p", "LD123456zhoudabao",
         "scp", tmp_path, f"root@123.57.29.111:/tmp/{skill_id}_pixar.png"],
        capture_output=True, text=True, timeout=60
    )
    if r.returncode != 0:
        logger.error(f"❌ scp 失败: {r.stderr}")
        return None
    # 在服务器上运行上传
    r2 = subprocess.run(
        ["sshpass", "-p", "LD123456zhoudabao",
         "ssh", "root@123.57.29.111",
         f"/root/gemini-audio-service/venv/bin/python3 /tmp/oss_upload.py {skill_id}"],
        capture_output=True, text=True, timeout=120
    )
    url = r2.stdout.strip()
    if url.startswith("https://"):
        logger.info(f"✅ 上传: skill_covers/{skill_id}_pixar.png ({len(data):,} bytes)")
        return url
    logger.error(f"❌ OSS 上传失败: {r2.stderr[:200]} | output: {url}")
    return None

def update_skill_md(skill_id: str, md_path: str, url: str):
    with open(md_path, "r", encoding="utf-8") as f:
        content = f.read()
    pattern = rf'(  - id: {re.escape(skill_id)}\n(?:(?!  - id:)[\s\S])*?    cover_image:) ""'
    new_content = re.sub(pattern, rf'\1 "{url}"', content)
    if new_content == content:
        logger.warning(f"⚠️ 未找到 cover_image 占位符 for {skill_id}")
    else:
        with open(md_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        logger.info(f"✅ 已写入 {md_path}: {skill_id}.cover_image")

results = {}

# 读取已有 URL 的跳过逻辑
def already_done(skill_id, md_path):
    try:
        with open(md_path) as f:
            content = f.read()
        import re
        pattern = rf'  - id: {re.escape(skill_id)}\n(?:(?!  - id:)[\s\S])*?    cover_image: "([^"]+)"'
        m = re.search(pattern, content)
        return bool(m and m.group(1).startswith("http"))
    except:
        return False

for skill_id, md_path, prompt in SKILLS:
    logger.info(f"\n{'='*50}\n处理: {skill_id}")
    if already_done(skill_id, md_path):
        logger.info(f"[{skill_id}] ⏭️ 已完成，跳过")
        results[skill_id] = "SKIPPED"
        continue
    data = generate_image(prompt, skill_id)
    if not data:
        logger.error(f"❌ 生成失败: {skill_id}")
        results[skill_id] = None
        time.sleep(1)
        continue
    url = upload_oss(data, skill_id)
    if url:
        update_skill_md(skill_id, md_path, url)
        results[skill_id] = url
    else:
        results[skill_id] = None
    time.sleep(1)

logger.info("\n汇总：")
for sid, url in results.items():
    if url:
        logger.info(f"  {sid}: ✅ {url}")
    else:
        logger.info(f"  {sid}: ❌ 失败")

success = sum(1 for v in results.values() if v)
logger.info(f"\n成功: {success} / 失败: {len(results)-success} / 总计: {len(results)}")
