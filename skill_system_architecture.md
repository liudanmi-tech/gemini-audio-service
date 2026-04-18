# 技能系统技术架构文档

> 更新日期：2026-04-18

---

## 目录

1. [整体架构概览](#整体架构概览)
2. [技能库结构](#技能库结构)
3. [iOS 43 个子技能注册表](#ios-43-个子技能注册表)
4. [自定义技能](#自定义技能)
5. [技能匹配流程（v2）](#技能匹配流程v2)
6. [技能执行流程](#技能执行流程)
7. [数据结构](#数据结构)
8. [完整数据流](#完整数据流)
9. [关键文件路径](#关键文件路径)

---

## 整体架构概览

```
用户上传音频
     │
     ▼
音频分析（Gemini）→ transcript（逐句转录 JSON）
     │
     ▼
技能匹配 v2（match_skills_v2）
  ├─ 读取用户偏好（UserSkillPreference）
  ├─ LLM 场景分类 + 相关度打分（classify_and_score）
  └─ 构建 skill_card stubs（含 execute_now 标记）
     │
     ▼
技能执行（_generate_strategies_core）
  ├─ execute_now=True  → 立即并发执行（LLM 调用）
  ├─ execute_now=False → 返回 pending stub（按需懒执行）
  └─ always_run        → emotion_recognition 始终执行
     │
     ▼
写入 StrategyAnalysis（PostgreSQL）
     │
     ▼
iOS 展示 skill_cards
```

---

## 技能库结构

### 文件系统布局

每个系统技能以目录形式存放于服务器 `/home/admin/gemini-audio-service/skills/<skill_id>/`：

```
skills/
├── workplace_jungle/
│   └── SKILL.md              # 技能定义文件
├── workplace_role/
│   └── SKILL.md
├── emotion_recognition/
│   └── SKILL.md
├── depression_prevention/
│   └── SKILL.md
└── ...（约 40 个目录）
```

可选扩展：
```
skills/<skill_id>/
├── SKILL.md
└── references/
    └── knowledge_base.md     # 技能专属知识库（注入 Prompt 末尾）
```

### SKILL.md 格式

```markdown
---
name: 职场丛林法则
description: 适用于职场沟通、上下级关系等场景
category: workplace        # 服务器旧分类（workplace/family/other）
priority: 100              # 越大越优先
version: "1.0.0"
enabled: true/false
keywords: ["老板", "同事"]
scenarios: ["上下级沟通"]
---

# 技能名称

## 技能概述
...

## Prompt模板

```prompt
角色: ...
任务: ...

对话转录:
{transcript_json}
```
```

关键 Prompt 变量：
| 变量 | 说明 |
|------|------|
| `{transcript_json}` | 对话转录 JSON |
| `{session_id}` | 当前会话 ID |
| `{user_id}` | 用户 ID |
| `{memory_context}` | 历史记忆上下文（v0.6+） |
| `{matched_sub_skill}` | 命中的子技能名称（v0.8+ 多维度） |

### 技能注册流程

```
SKILL.md 文件
     │
     ▼ loader.parse_skill_markdown()
   解析 frontmatter + Prompt 模板
     │
     ▼ registry.register_skill()
   写入 PostgreSQL skills 表
   （prompt_template 落表，后续不再读文件）
     │
     ▼ registry.get_skill()
   读 DB → 执行
```

---

## iOS 43 个子技能注册表

**文件**：`/home/admin/gemini-audio-service/skills/ios_skill_registry.py`

### 6 大分类

| iOS Category | 场景描述 | 技能数量 |
|---|---|---|
| `work_life` | 职场/薪资/同事/上司/求职 | 8 |
| `campus_life` | 校园/学业/导师/室友/实习 | 7 |
| `relationships` | 恋爱/友谊/分手/友情 | 7 |
| `family` | 家庭/父母/共育/青少年 | 7 |
| `personal_growth` | 自我提升/焦虑/愤怒/自尊 | 7 |
| `life_skills` | 医疗/理财/邻居/房东/消费者权益 | 7 |

**总计：43 个系统子技能**

### 执行模板常量

```python
EXEC_WORK_LIFE       = "_exec_work_life"
EXEC_CAMPUS_LIFE     = "_exec_campus_life"
EXEC_RELATIONSHIPS   = "_exec_relationships"
EXEC_FAMILY          = "_exec_family"
EXEC_PERSONAL_GROWTH = "_exec_personal_growth"
EXEC_LIFE_SKILLS     = "_exec_life_skills"
EXEC_CUSTOM          = "_exec_custom"
```

每个模板对应一套固定的系统 Prompt（按分类定制语气和分析框架）。

### 子技能结构示例

```python
"salary_negotiation": {
    "category":      "work_life",
    "name":          "Salary Negotiation",
    "exec_template": "_exec_work_life",
    "exec_context": {
        "focus":        "salary or compensation negotiation",
        "sub_skill_cn": "薪资谈判",
        "angle":        "how to anchor, counter-offer, and close without burning bridges",
    },
},
```

### 完整 43 个子技能列表

**work_life（职场）**
- `salary_negotiation` — 薪资谈判
- `difficult_boss` — 向上管理
- `work_boundaries` — 职场边界
- `performance_reviews` — 绩效沟通
- `feedback` — 反馈沟通
- `job_interviews` — 面试沟通
- `coworker_conflicts` — 同事冲突
- `remote_work` — 远程沟通

**campus_life（校园）**
- `study_pressure`（含 campus_life 子技能群）
- 含导师沟通、室友矛盾、小组项目、实习 offer 等 7 个子技能

**relationships（关系）**
- 含恋爱沟通、分手对话、友谊边界、来出柜等 7 个子技能

**family（家庭）**
- 含亲子沟通、与父母边界、跨代际冲突、共育决策等 7 个子技能

**personal_growth（个人成长）**
- 含愤怒管理、焦虑调节、内心批评、自我价值等 7 个子技能

**life_skills（生活技能）**
- 含医疗沟通、消费者投诉、房东谈判、财务对话等 7 个子技能

---

## 自定义技能

### 标识规则

- 系统技能 ID：`salary_negotiation`、`difficult_boss` 等
- 自定义技能 ID：`custom_{uuid}`，如 `custom_3f8a2b1c-...`
- `is_custom = sid.startswith("custom_")`

### 数据库存储

```sql
-- CustomSkill 表（用户自建技能）
CREATE TABLE custom_skills (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    skill_id    VARCHAR NOT NULL,  -- custom_{uuid}
    name        VARCHAR NOT NULL,
    description TEXT,
    prompt      TEXT,              -- 用户写的 Prompt
    created_at  TIMESTAMP
);
```

### 执行模板

自定义技能使用 `EXEC_CUSTOM` 模板：直接将用户写的 Prompt 注入，不套用系统 6 大分类的预设框架。

---

## 技能匹配流程（v2）

**入口函数**：`skills/router.py: match_skills_v2()`
**调用时机**：音频转录完成后，在 `_generate_strategies_core()` 内触发

### 完整匹配流程

```
上传录音 → Gemini 转录 → transcript JSON
                              │
                              ▼
         _generate_strategies_core()
                              │
              ┌───────────────┴────────────────────┐
              │  前置：查 speaker_mapping → 加载档案关系   │
              └───────────────┬────────────────────┘
                              │
                              ▼
              match_skills_v2(transcript, profiles, user_id, db)
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
   Step1: 读偏好         Step2: 档案强制       Step3: 构建 stub
 UserSkillPreference      _forced_category       手动/自动模式
         │                    │                    │
         └────────────────────┴────────────────────┘
                              │
                              ▼
              _append_always_run()  追加固定技能
              emotion_recognition（始终）
              depression_prevention（条件触发）
                              │
                              ▼
              返回 stub 列表（含 execute_now 标记）
```

---

### Step 1：读用户偏好

查询 `user_skill_preferences` 表，获取：
- `is_manual`：是否手动模式（`skill_id="__manual_mode__"` 行的 `selected` 值）
- `selected_ids`：用户已勾选的技能 ID 列表（系统子技能 ID 或 `custom_{uuid}`）

**新用户兜底**：若该用户从未设置偏好（`selected_ids` 为空），直接使用全部 43 个系统技能参与匹配。

---

### Step 2：档案关系强制覆盖

在 `match_skills_v2` 调用前，`_generate_strategies_core` 已通过 `speaker_mapping` 查出本次对话参与者的档案，提取 `relationship_type`。

`_forced_category_from_profiles()` 按以下规则覆盖 `primary_category`：

| 档案 relationship_type | 强制分类 |
|---|---|
| 领导/上级/老板/总监/经理/主管/同事/客户/下属 等 | `work_life` |
| 老婆/丈夫/爸爸/妈妈/儿子/女儿/孩子/兄弟/姐妹 等 | `family` |
| 其他/自己/无 | 不强制，由 LLM 决定 |

此强制结果优先级高于 LLM 分类结果。

---

### Step 3a：自动模式（默认）

调用 `classify_and_score()`，**一次 LLM 调用**同时完成两件事：

**输入给 LLM：**
```
6 大分类描述（work_life / campus_life / relationships / family / personal_growth / life_skills）
+ 用户选中的所有技能 ID、英文名、用途描述
+ 完整对话 transcript
```

**LLM 返回 JSON：**
```json
{
  "primary_category": "work_life",
  "scene_description": "用户在和上司讨论薪资调整...",
  "skill_scores": {
    "salary_negotiation": 91,
    "difficult_boss":     78,
    "performance_reviews":45,
    "partner_communication": 12
  }
}
```

**兜底规则：**
- LLM 返回非法分类 → 默认 `work_life`
- 某技能缺失分数 → 补 `50`
- LLM 完全失败 → 全部技能 `50` 分，primary 用第一个技能的分类

然后 `_build_stubs_auto()` 按以下规则构建：
- 按 iOS 分类分组，每组**按分数降序，最多取 top-5**
- 档案强制或 LLM 得出的 `primary_category` 所在组**排在最前面**
- 每组**分数第一名** `execute_now=True`，其余 `execute_now=False`（pending）

**示例 stub 列表（职场对话，用户选了 8 个技能）：**

```
emotion_recognition     always    execute_now=True   score=null  ← 始终置顶
salary_negotiation      work_life execute_now=True   score=91    ← primary 组第1名，立即执行
difficult_boss          work_life execute_now=False  score=78    ← pending
coworker_conflicts      work_life execute_now=False  score=65    ← pending
performance_reviews     work_life execute_now=False  score=45    ← pending
partner_communication   relationship execute_now=True score=30   ← 本组第1名，立即执行
breakups                relationship execute_now=False score=10  ← pending
```

---

### Step 3b：手动模式

跳过 LLM 场景分类，直接使用用户在 iOS 里勾选的技能：
- 按 iOS 分类分组
- 每组**第一个**（列表顺序）`execute_now=True`，其余 pending
- 所有 `score=null`（无相关度分数）

---

### Step 4：追加始终运行技能（_append_always_run）

无论手动/自动，最终 stub 列表**头部**插入：

| 技能 | 触发条件 | execute_now |
|------|---------|------------|
| `emotion_recognition` | 始终 | `True` |
| `depression_prevention` | 用户话术含危机词，或字数≥50且含"崩溃/废物/没用"等 | `True` |

---

### Stub 完整结构

```python
{
    "skill_id":      "salary_negotiation",   # iOS sub-skill ID
    "skill_name":    "Salary Negotiation",
    "category":      "work_life",            # iOS 6 大分类
    "score":         91,                     # 0-100，手动模式为 None
    "is_custom":     False,
    "exec_template": "_exec_work_life",      # 执行模板常量
    "exec_context":  {
        "focus":        "salary or compensation negotiation",
        "sub_skill_cn": "薪资谈判",
        "angle":        "how to anchor, counter-offer, ...",
    },
    "execute_now":   True,                   # True=立即执行，False=pending
    "always_run":    False,                  # emotion/depression=True
    "content_type":  "pending",
    "content":       None,                   # 执行后填充
}
```

---

## 技能执行流程

**入口函数**：`main.py: _generate_strategies_core()`

### 执行策略

```
stub 列表
   │
   ├─ execute_now=True  → 并发 asyncio.gather() → LLM 调用 → strategy 卡片
   └─ execute_now=False → 原样写库（content=null，等用户按需触发）
```

具体代码逻辑：
```python
execute_now_stubs = [s for s in matched_skills if s.get("execute_now", False)]
pending_stubs     = [s for s in matched_skills if not s.get("execute_now", False)]

# 并发执行 execute_now 技能
results = await asyncio.gather(
    *[_run_one_skill(sid, stub, _resolve_prompt_for_stub(stub))
      for stub in execute_now_stubs],
    return_exceptions=True,
)

# pending 技能：直接标记写入 skill_cards，content=None
for stub in pending_stubs:
    skill_results.append({"is_pending": True, ...})
```

---

### Prompt 来源查找（_resolve_prompt_for_stub）

每个 `execute_now` 技能在执行前，按以下**优先级顺序**查找 prompt_template：

```
技能 skill_id
     │
     ├─ 1. always_run 技能（emotion_recognition / depression_prevention）
     │      → 直接读 skills 数据库表中的 prompt_template
     │
     ├─ 2. 自定义技能（custom_{uuid}）
     │      → 读 CustomSkill 表的 markdown_content（用户自写 prompt）
     │
     ├─ 3. work_life 子技能 → 查 _WORK_LIFE_EXEC_SKILL_MAP → 读对应服务器技能 prompt
     │      salary_negotiation  → workplace_scenario  prompt
     │      difficult_boss      → workplace_role      prompt
     │      work_boundaries     → workplace_psychology prompt
     │      performance_reviews → workplace_role      prompt
     │      feedback            → workplace_capability prompt
     │      job_interviews      → workplace_scenario  prompt
     │      coworker_conflicts  → workplace_scenario  prompt
     │      remote_work         → workplace_capability prompt
     │
     ├─ 4. relationships / family 子技能 → 查 _FAMILY_EXEC_SKILL_MAP
     │      partner_communication → family_relationship prompt
     │      talking_stage         → family_relationship prompt
     │      ghosting_rejection    → family_relationship prompt
     │      situationship         → family_relationship prompt
     │      dtr_conversation      → family_relationship prompt
     │      breakups              → couple_intimacy    prompt
     │      friendship_conflicts  → family_conflict    prompt
     │      coming_out            → family_relationship prompt
     │      parent_boundaries     → family_boundary    prompt
     │      immigrant_family      → family_relationship prompt
     │      family_money          → couple_finance     prompt
     │      coparenting           → couple_decision    prompt
     │      parent_teen           → teen_communication prompt
     │      coming_out_family     → family_boundary    prompt
     │
     ├─ 5. personal_growth 子技能 → 查 _PERSONAL_EXEC_SKILL_MAP
     │      assertiveness      → inner_critic      prompt
     │      imposter_syndrome  → self_worth        prompt
     │      social_anxiety     → anxiety_management prompt
     │      burnout_recovery   → burnout_recovery  prompt
     │      anger_management   → anger_regulation  prompt
     │      friend_crisis      → resilience_build  prompt
     │      dealing_criticism  → inner_critic      prompt
     │      boundary_setting   → family_boundary   prompt
     │
     ├─ 6. campus_life / life_skills → 使用内置 PROMPT_CAMPUS_LIFE / PROMPT_LIFE_SKILLS
     │      （填充 {focus} {angle} {sub_skill_cn} 变量，无需查数据库）
     │
     └─ 7. 兜底 → workplace_scenario prompt（降级，保证不崩）
```

---

### 执行后的 skill_card 构建

每个技能执行完毕后，根据返回类型构建不同格式的卡片写入 `skill_cards` 数组：

| 返回类型 | content_type | 说明 |
|---------|------------|------|
| `result.visual + result.strategies` | `"strategy"` | 正常策略卡，含关键时刻和策略列表 |
| `emotion_insight` | `"emotion"` | 情绪卡，含叹气/哈哈次数、情绪状态 |
| `mental_health_insight` | `"mental_health"` | 防抑郁卡，含认知三联征 |
| `is_pending=True` | `"pending"` | pending 卡，content=null |

**各技能各自一张卡片，不合并**（composer.py 的合并逻辑已不再使用）。

---

### 情绪识别技能（executor.py）

执行流程：
1. 提取用户自己的话术（`is_me=True` 的行）
2. 规则统计：叹气词次数、哈哈次数、字数
3. LLM 判断情绪状态（`高兴/焦虑/平常心/亢奋/悲伤`）

返回结构：
```python
{
    "emotion_insight": {
        "sigh_count":  2,
        "haha_count":  0,
        "mood_state":  "焦虑",
        "mood_emoji":  "😰",
        "char_count":  358,
    }
}
```

### 防抑郁监控技能（executor.py）

触发条件（任意一项）：
- 命中危机词：`不想活 / 想活了 / 活不下去 / 死了算了 / 想死 / 自杀`
- 用户话术字数 ≥ 50 且命中一般词：`搞砸 / 没用 / 失败 / 我不配 / 废物 / 崩溃 / 压力大` 等

返回结构：
```python
{
    "mental_health_insight": {
        "defense_energy_pct": 65,
        "dominant_defense":   "合理化",
        "status_assessment":  "...",
        "cognitive_triad": {
            "self":   {"status": "yellow", "reason": "..."},
            "world":  {"status": "green",  "reason": "..."},
            "future": {"status": "red",    "reason": "..."},
        },
        "insight":     "...",
        "strategy":    "...",
        "crisis_alert": False,
    }
}
```

### 关键数量限制

| 维度 | 限制 |
|------|------|
| 每个 iOS 分类最多取 | top-5（按 score 降序） |
| 每个分类立即执行数 | 1（仅第一名 execute_now=True） |
| 单次对话最多并发 LLM 调用 | 通常 2-4 个（各分类第一名 + emotion） |
| 每张策略卡的关键时刻 | 2-5 个 visual |
| 每张策略卡的策略数 | 3 个 strategies |

---

## 数据结构

### 数据库表

```sql
-- 系统技能定义（从 SKILL.md 加载）
CREATE TABLE skills (
    id              UUID PRIMARY KEY,
    skill_id        VARCHAR UNIQUE NOT NULL,
    name            VARCHAR NOT NULL,
    description     TEXT,
    category        VARCHAR,
    skill_path      VARCHAR,
    priority        INTEGER DEFAULT 0,
    enabled         BOOLEAN DEFAULT TRUE,
    version         VARCHAR DEFAULT '1.0.0',
    prompt_template TEXT,          -- SKILL.md 内容落表
    meta_data       JSONB,         -- keywords/scenarios/sub_skills 等
    created_at      TIMESTAMP,
    updated_at      TIMESTAMP
);

-- 用户技能偏好（iOS 技能库勾选状态）
CREATE TABLE user_skill_preferences (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    skill_id    VARCHAR NOT NULL,   -- iOS sub-skill ID 或 custom_{uuid}
    selected    BOOLEAN DEFAULT TRUE,
    created_at  TIMESTAMP,
    -- skill_id = "__manual_mode__" 时，selected 表示手动模式开关
);

-- 用户自定义技能
CREATE TABLE custom_skills (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    skill_id    VARCHAR NOT NULL,   -- custom_{uuid}
    name        VARCHAR NOT NULL,
    description TEXT,
    prompt      TEXT,
    created_at  TIMESTAMP
);

-- 策略分析结果（每次对话一条）
CREATE TABLE strategy_analysis (
    id          UUID PRIMARY KEY,
    session_id  UUID UNIQUE NOT NULL,
    user_id     UUID NOT NULL,
    skill_cards JSONB,              -- skill_card 数组
    scene_type  VARCHAR,
    scene_data  JSONB,
    created_at  TIMESTAMP
);
```

### skill_cards JSONB 格式

```json
[
  {
    "skill_id":   "salary_negotiation",
    "skill_name": "Salary Negotiation",
    "category":   "work_life",
    "score":      91,
    "is_custom":  false,
    "content_type": "skill_card",
    "content": {
      "visual": [
        {
          "transcript_index": 3,
          "speaker": "Speaker_0",
          "image_prompt": "...",
          "emotion": "紧张",
          "subtext": "...",
          "context": "...",
          "my_inner": "...",
          "other_inner": "..."
        }
      ],
      "strategies": [
        {
          "id": "s1",
          "label": "直接锚定",
          "emoji": "⚓",
          "title": "Say the Number First",
          "content": "..."
        }
      ]
    }
  },
  {
    "skill_id":   "emotion_recognition",
    "skill_name": "Emotion Recognition",
    "always_run": true,
    "content_type": "emotion",
    "content": {
      "emotion_insight": {
        "sigh_count": 0,
        "haha_count": 1,
        "mood_state": "焦虑",
        "mood_emoji": "😰",
        "char_count": 245
      }
    }
  },
  {
    "skill_id":    "difficult_boss",
    "skill_name":  "Difficult Boss",
    "score":       67,
    "content_type": "pending",
    "content":     null
  }
]
```

### iOS 数据模型（Swift）

```swift
struct SkillCard: Codable {
    let skill_id:     String
    let skill_name:   String?
    let category:     String?
    let score:        Int?         // 相关度分数，手动模式为 nil
    let is_custom:    Bool?
    let content_type: String       // "skill_card" | "emotion" | "pending"
    let always_run:   Bool?
    let content:      SkillCardContent?
}

struct SkillCardContent: Codable {
    let visual:          [VisualData]?
    let strategies:      [StrategyItem]?
    let emotion_insight: EmotionInsight?
    let mental_health_insight: MentalHealthInsight?
}
```

---

## 完整数据流

```
1. 音频上传
   iOS → POST /api/v1/sessions/upload-and-analyze

2. 音频分析（main.py）
   Gemini Files API（new SDK）→ transcript JSON

3. 技能匹配（skills/router.py: match_skills_v2）
   PostgreSQL UserSkillPreference
   → classify_and_score（单次 LLM）
   → stubs 列表（execute_now/pending 标记）

4. 技能执行（main.py: _generate_strategies_core）
   并发执行 execute_now stubs → LLM 调用
   pending stubs → 原样保留（content=None）

5. 情绪分析（executor._execute_emotion_skill）
   规则统计 + LLM 判断 → emotion_insight

6. 写入 PostgreSQL
   strategy_analysis.skill_cards = [...] (JSONB)

7. iOS 读取（Beijing read replica）
   GET /api/v1/sessions/{id}/strategy
   → StrategyAnalysisResponse.skill_cards

8. 懒执行（pending 技能按需获取）
   iOS → POST /api/v1/sessions/{id}/skills/{skill_id}/execute/stream
   → SSE 流式返回纯文本分析结果
```

---

## 关键文件路径

### 服务器（Singapore: /home/admin/gemini-audio-service/）

| 文件 | 职责 |
|------|------|
| `skills/ios_skill_registry.py` | 43 个 iOS 子技能定义 + 6 大分类 + 执行模板常量 |
| `skills/router.py` | `match_skills_v2()` + `classify_and_score()` |
| `skills/executor.py` | `execute_skill()` + 情绪/防抑郁特殊处理 |
| `skills/registry.py` | 技能注册表（DB 缓存 + 文件系统扫描） |
| `skills/loader.py` | SKILL.md 解析 + 知识库加载 |
| `skills/composer.py` | 多技能结果合并去重 |
| `main.py` | `_generate_strategies_core()` + `_resolve_prompt_for_stub()` |
| `database/models.py` | Skill / CustomSkill / UserSkillPreference / StrategyAnalysis 表 |

### iOS（/Users/liudan/Desktop/0226new/Models.swift/WorkSurvivalGuide/）

| 文件 | 职责 |
|------|------|
| `Models/VisualData.swift` | SkillCard / SkillCardContent / EmotionInsight / StrategyItem |
| `Services/NetworkManager.swift` | API 调用（读北京，写新加坡） |
| `Views/StrategyAnalysisView_Updated.swift` | 技能卡片展示 UI |

---

## 注意事项

1. **技能 ID 命名空间**：iOS sub-skill ID（`salary_negotiation`）与服务器旧技能 ID（`workplace_jungle`）是两套不同的命名空间。iOS 流程使用 `ios_skill_registry.py`；旧版场景分类流程使用 `skills/registry.py` + `skills/router.py`（已废弃）。

2. **新用户兜底**：若用户未设置任何技能偏好，`match_skills_v2` 会使用全部 43 个系统技能执行，避免首次分析没有输出。

3. **手动模式**：用户在 iOS 手动勾选技能时，`__manual_mode__` 标志写入 `UserSkillPreference`，跳过场景分类 LLM 调用，直接使用勾选结果。

4. **pending 技能**：`execute_now=False` 的技能不会在音频分析时执行，节省时间。iOS 需要时可调用 `/skills/{skill_id}/execute/stream` SSE 接口懒加载。

5. **分数字段**：`score` 为 `0-100` 整数（自动模式）或 `null`（手动模式）。iOS 展示时 `score ≥ 70` 可标注高相关度。
