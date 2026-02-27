# 职场生存指南（WorkSurvivalGuide）完整技术文档

> 文档生成时间：2026-02-27
> 项目版本：v0.8（技能分类重构）

---

## 目录

1. [项目概述](#1-项目概述)
2. [系统架构](#2-系统架构)
3. [技术栈](#3-技术栈)
4. [数据库设计](#4-数据库设计)
5. [后端服务设计](#5-后端服务设计)
6. [API 接口文档](#6-api-接口文档)
7. [技能系统设计](#7-技能系统设计)
   - [7.9 iOS 技能库 — 用户视角（技能目录）](#79-ios-技能库--用户视角技能目录)
8. [AI 分析流程](#8-ai-分析流程)
9. [iOS 客户端设计](#9-ios-客户端设计)
10. [部署架构](#10-部署架构)
11. [环境变量配置](#11-环境变量配置)
12. [Pydantic 数据模型](#12-pydantic-数据模型)
13. [错误码与状态说明](#13-错误码与状态说明)
14. [北京服务器架构（只读节点）](#14-北京服务器架构只读节点)

---

## 1. 项目概述

**职场生存指南**是一款以"AI 军师"为核心理念的对话录音分析应用。用户录制职场、家庭等场景的对话音频，系统通过 Google Gemini AI 完成语音转录、情绪分析、场景识别，并根据匹配的技能库生成个性化的策略建议和视觉化插图，帮助用户复盘沟通、保护利益。

### 核心功能

| 功能模块 | 描述 |
|---|---|
| 录音上传 | iOS 端实时录音或导入本地音频文件 |
| AI 语音分析（Call #1） | Gemini 转录对话、识别说话人、计算情绪分数 |
| 场景识别 | 自动分类职场/家庭/其他，支持多维度职场分析 |
| 技能匹配 | 根据场景动态匹配并执行策略技能 |
| 策略生成（Call #2） | 技能 Prompt 驱动，输出局势分析、应对策略 |
| 图片生成 | 使用 Gemini 图片模型生成 AI 插画，支持 15 种风格 |
| 档案管理 | 用户可创建人物档案并与声纹片段绑定 |
| 技能库 | 管理员可在服务器侧维护技能文件，热重载生效 |

---

## 2. 系统架构

```
┌──────────────────────────────────────────────────────────────────────┐
│                          iOS 客户端                                   │
│  SwiftUI App (WorkSurvivalGuide)                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────────┐ │
│  │ 录音/上传 │  │  任务列表 │  │  档案管理 │  │  技能库 / 策略 / 星图  │ │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────────┬───────────┘ │
│       │             │             │                    │              │
│       └─────────────┴─────────────┴────────────────────┘             │
│                    NetworkManager (Alamofire)                         │
│         写/上传 → 新加坡节点       读 → 北京节点                       │
└──────────┬──────────────────────────────┬────────────────────────────┘
           │ 写请求                        │ 读请求
           ▼                              ▼
┌──────────────────────┐      ┌──────────────────────────────────┐
│  新加坡 ECS           │      │  北京 ECS                         │
│  47.79.254.213        │      │  123.57.29.111:8000               │
│                      │      │                                  │
│  Nginx (port 80)     │      │  FastAPI main_read.py            │
│  ├─ /api/ → :8000    │      │  Uvicorn port 8000               │
│  └─ /secret-channel  │      │  (只读 API，无 Gemini 调用)        │
│     → Gemini API     │      │  ┌────────────────────────────┐  │
│                      │      │  │ /api/v1/auth               │  │
│  FastAPI main.py     │      │  │ /api/v1/tasks (GET only)   │  │
│  Uvicorn port 8000   │      │  │ /api/v1/skills             │  │
│  4 workers           │      │  │ /api/v1/profiles           │  │
│  ┌──────────────────┐│      │  │ /api/v1/galaxy/overview    │  │
│  │ 核心分析流水线    ││      │  │ /api/v1/images/{sid}/{i}   │  │
│  │ POST /audio/upload││      │  │ /health                    │  │
│  │ analyze_audio_    ││      │  └────────────────────────────┘  │
│  │   async()         ││      │  ※ 无 Nginx，无 Gemini 代理       │
│  │ Call #1: 转录     ││      │  ※ systemd 服务未启用             │
│  │ 技能匹配/执行     ││      └──────────────┬───────────────────┘
│  │ 图片生成          ││                     │
│  └──────────────────┘│                     │
└──────────┬───────────┘                     │
           │                                 │
           └──────────────┬──────────────────┘
                          │ 共享同一 RDS 实例
                          ▼
           ┌─────────────────────────────┐
           │  阿里云 RDS PostgreSQL       │
           │  pgm-2ze5w19pz5t064k04o     │
           │  .pg.rds.aliyuncs.com:5432  │
           │  database: gemini_audio_db  │
           │  - users                    │
           │  - sessions                 │
           │  - analysis_results         │
           │  - strategy_analysis        │
           │  - skills                   │
           │  - skill_executions         │
           │  - profiles                 │
           │  - verification_codes       │
           │  - user_skill_preferences   │
           └──────────────┬──────────────┘
                          │
           ┌──────────────┴──────────────┐
           │  阿里云 OSS                  │
           │  Bucket: geminipicture2     │
           │  Region: oss-cn-beijing     │
           │  images/{uid}/{sid}/*.png   │
           │  (北京/新加坡共用同一 Bucket) │
           └─────────────────────────────┘

                  新加坡 ECS 独有：
           ┌─────────────────────────────┐
           │  Google Gemini API           │
           │  经 Nginx /secret-channel    │
           │  反向代理访问（解决国内封锁） │
           │  - gemini-3-flash-preview   │
           │  - gemini-2.5-flash-image   │
           └─────────────────────────────┘
```

---

## 3. 技术栈

### 后端

| 组件 | 版本 | 用途 |
|---|---|---|
| Python | 3.12+ | 主要语言 |
| FastAPI | ≥0.104 | Web 框架，异步 |
| Uvicorn | ≥0.24 | ASGI 服务器 |
| SQLAlchemy | ≥2.0 | ORM（异步） |
| asyncpg | ≥0.29 | PostgreSQL 异步驱动 |
| google-generativeai | ≥0.8 | Gemini 语音/文本 API |
| google-genai | ≥0.2 | Gemini 图片生成 API |
| oss2 | ≥2.18 | 阿里云 OSS SDK |
| python-jose | ≥3.3 | JWT 签发与验证 |
| pydub | ≥0.25 | 音频分片（大文件处理） |
| mem0ai | ≥0.1 | 记忆与知识图谱（v0.6+） |
| pyyaml | ≥6.0 | SKILL.md frontmatter 解析 |

### 前端（iOS）

| 组件 | 版本 | 用途 |
|---|---|---|
| SwiftUI | iOS 16+ | UI 框架 |
| Alamofire | - | HTTP 网络请求 |
| AVFoundation | - | 录音/音频播放 |
| Combine | - | 响应式状态管理 |
| CoreBluetooth | - | 蓝牙设备（蓝牙耳机录音） |

### 基础设施

| 组件 | 用途 |
|---|---|
| 阿里云 ECS（新加坡） | 主服务器，写/上传/分析 |
| 阿里云 ECS（北京） | 只读节点，加速中国用户读请求 |
| 阿里云 RDS PostgreSQL | 数据库 |
| 阿里云 OSS | 图片、音频文件对象存储 |
| Nginx | 反向代理，SSL，大文件，Gemini 代理 |
| systemd | 进程管理与开机自启 |
| ffmpeg | 音频切段（extract-segment） |

---

## 4. 数据库设计

**数据库**：PostgreSQL（通过阿里云 RDS 托管）
**ORM**：SQLAlchemy 2.x 异步模式
**连接池**：pool_size=20, max_overflow=30, pool_recycle=3600

### 4.1 ER 图（简化）

```
users ──< sessions ──< analysis_results
  │             └────< strategy_analysis
  │
  ├──< profiles
  │
  └──< user_skill_preferences

skills ──< skill_executions >── sessions

verification_codes （独立，不关联 users）
```

### 4.2 表结构详情

#### `users` — 用户表

```sql
CREATE TABLE users (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone       VARCHAR(11) UNIQUE NOT NULL,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW(),
  last_login_at TIMESTAMPTZ,
  is_active   BOOLEAN DEFAULT TRUE
);
CREATE INDEX idx_users_phone ON users(phone);
```

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | UUID | PK, NOT NULL | 用户唯一标识（auto-generated） |
| phone | VARCHAR(11) | UNIQUE, NOT NULL | 手机号（登录凭据） |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | 注册时间 |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | 更新时间 |
| last_login_at | TIMESTAMPTZ | NULL | 最后登录时间（首次登录前为 null） |
| is_active | BOOLEAN | DEFAULT TRUE | 是否启用（软删除） |

---

#### `sessions` — 会话/任务表

```sql
CREATE TABLE sessions (
  id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id               UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title                 VARCHAR(255),
  start_time            TIMESTAMPTZ,
  end_time              TIMESTAMPTZ,
  duration              INTEGER,
  status                VARCHAR(50),
  error_message         TEXT,
  analysis_stage        VARCHAR(100),
  analysis_stage_detail JSONB,
  emotion_score         INTEGER,
  speaker_count         INTEGER,
  tags                  TEXT[],
  audio_url             VARCHAR(500),
  audio_path            VARCHAR(500),
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_sessions_user_id    ON sessions(user_id);
CREATE INDEX idx_sessions_created_at ON sessions(created_at DESC);
```

| 字段 | 类型 | 约束 | 说明 |
|---|---|---|---|
| id | UUID | PK | session_id（与 audio_id 一致） |
| user_id | UUID | FK→users, NOT NULL | 所属用户 |
| title | VARCHAR(255) | NULL | 录音标题（如"录音 14:23"） |
| start_time | TIMESTAMPTZ | NULL | 录音开始时间 |
| end_time | TIMESTAMPTZ | NULL | 录音结束时间 |
| duration | INTEGER | NULL | 时长（秒） |
| status | VARCHAR(50) | NULL | `analyzing` / `completed` / `archived` / `failed` |
| error_message | TEXT | NULL | 分析失败时的错误描述 |
| analysis_stage | VARCHAR(100) | NULL | 当前分析阶段（见进度枚举） |
| analysis_stage_detail | JSONB | NULL | 阶段附加信息，如 `{"skills_matched": 3, "skill_names": [...]}` |
| emotion_score | INTEGER | NULL | 情绪分数 0-100 |
| speaker_count | INTEGER | NULL | 说话人数 |
| tags | TEXT[] | NULL | 标签数组（如 `["#职场", "#PUA预警"]`） |
| audio_url | VARCHAR(500) | NULL | 原音频 OSS URL（启用 OSS 时） |
| audio_path | VARCHAR(500) | NULL | 原音频本地路径（未启用 OSS 时） |
| created_at | TIMESTAMPTZ | DEFAULT NOW() | 创建时间 |
| updated_at | TIMESTAMPTZ | DEFAULT NOW() | 更新时间 |

**分析阶段枚举（analysis_stage）**：

| 阶段值 | 含义 | iOS 展示文案 |
|---|---|---|
| `upload_done` | 上传完成 | 上传完成 |
| `saving_audio` | 保存音频中 | 保存音频… |
| `transcribing` | Gemini 转录中 | 转写音频… |
| `matching_profiles` | 声纹匹配中 | 匹配档案… |
| `strategy_scene` | 场景识别中 | 识别场景… |
| `strategy_matching` | 技能匹配中 | 匹配技能… |
| `strategy_matched_n` | 已匹配 N 个技能 | 匹配了 N 个技能 |
| `strategy_executing` | 技能执行中 | 技能加工中… |
| `strategy_images` | 图片生成中 | 生成图片中… |
| `strategy_done` | 策略完成 | 策略就绪 |
| `oss_upload` | OSS 上传中 | 正在上传到云端… |

---

#### `analysis_results` — 分析结果表

```sql
CREATE TABLE analysis_results (
  id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id           UUID NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE CASCADE,
  dialogues            JSONB NOT NULL DEFAULT '[]',
  risks                TEXT[],
  summary              TEXT,
  mood_score           INTEGER,
  stats                JSONB DEFAULT '{}',
  transcript           TEXT,
  call1_result         JSONB,
  speaker_mapping      JSONB DEFAULT '{}',
  conversation_summary TEXT,
  created_at           TIMESTAMPTZ DEFAULT NOW(),
  updated_at           TIMESTAMPTZ DEFAULT NOW()
);
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID (PK) | — |
| session_id | UUID (FK→sessions, UNIQUE) | 一对一关联 |
| dialogues | JSONB, DEFAULT `[]` | 对话列表，格式：`[{"speaker":"Speaker_0","text":"...","timestamp":"00:05","is_me":false}]` |
| risks | TEXT[] | 风险点列表，如 `["权力不平衡", "PUA 迹象"]` |
| summary | TEXT | 对话总结（100-200字） |
| mood_score | INTEGER | Gemini 情绪评分（0-100） |
| stats | JSONB, DEFAULT `{}` | 统计：`{"sigh_count": 2, "laugh_count": 5}` |
| transcript | TEXT | 原始转录文本（未格式化） |
| call1_result | JSONB | Call #1 完整原始响应 |
| speaker_mapping | JSONB, DEFAULT `{}` | 声纹映射：`{"Speaker_0": "<profile_uuid>", "Speaker_1": "<profile_uuid>"}` |
| conversation_summary | TEXT | "谁和谁对话"二次总结，由 Gemini 生成 |

---

#### `strategy_analysis` — 策略分析表

```sql
CREATE TABLE strategy_analysis (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id       UUID NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE CASCADE,
  visual_data      JSONB DEFAULT '[]',
  strategies       JSONB DEFAULT '[]',
  applied_skills   JSONB DEFAULT '[]',
  scene_category   VARCHAR(50),
  scene_confidence FLOAT,
  skill_cards      JSONB DEFAULT '[]',
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID (PK) | — |
| session_id | UUID (FK→sessions, UNIQUE) | 一对一关联 |
| visual_data | JSONB, DEFAULT `[]` | 旧版视觉数据数组（VisualData[]），已被 skill_cards 取代 |
| strategies | JSONB, DEFAULT `[]` | 旧版策略数组（StrategyItem[]），已被 skill_cards 取代 |
| applied_skills | JSONB, DEFAULT `[]` | 已执行的技能列表 `[{"skill_id": "...", "priority": 100}]` |
| scene_category | VARCHAR(50) | 识别的主场景（workplace/family/personal/other） |
| scene_confidence | FLOAT | 主场景置信度（0.0-1.0） |
| skill_cards | JSONB, DEFAULT `[]` | **新版**：每技能一张卡片，详见 7.7 节 |

---

#### `skills` — 技能库表

```sql
CREATE TABLE skills (
  skill_id        VARCHAR(100) PRIMARY KEY,
  name            VARCHAR(200) NOT NULL,
  description     TEXT,
  category        VARCHAR(50) NOT NULL,
  skill_path      VARCHAR(500) NOT NULL,
  priority        INTEGER DEFAULT 0,
  enabled         BOOLEAN DEFAULT TRUE,
  version         VARCHAR(50),
  prompt_template TEXT,
  metadata        JSONB DEFAULT '{}',
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_skills_category ON skills(category);
CREATE INDEX idx_skills_enabled  ON skills(enabled);
```

| 字段 | 类型 | 说明 |
|---|---|---|
| skill_id | VARCHAR(100) (PK) | 技能唯一 ID，如 `workplace_role` |
| name | VARCHAR(200), NOT NULL | 技能名称 |
| description | TEXT | 技能描述 |
| category | VARCHAR(50), NOT NULL | 分类：`workplace` / `family` / `personal` |
| skill_path | VARCHAR(500), NOT NULL | 技能目录路径，如 `skills/workplace_role` |
| priority | INTEGER, DEFAULT 0 | 优先级，数值越高越先执行 |
| enabled | BOOLEAN, DEFAULT TRUE | 是否启用 |
| version | VARCHAR(50) | 版本号 |
| prompt_template | TEXT | Prompt 模板（从 SKILL.md `## Prompt模板` 节提取后落库） |
| metadata | JSONB, DEFAULT `{}` | 元数据：`{keywords, scenarios, sub_skills, display_description, cover_color, dimension}` |

**metadata.sub_skills 结构**：
```json
[
  {"id": "managing_up",   "name": "向上管理",   "description": "...", "cover_color": "#5E7C8B"},
  {"id": "managing_down", "name": "向下管理",   "description": "...", "cover_color": "#6B8E7C"}
]
```

---

#### `skill_executions` — 技能执行记录表

```sql
CREATE TABLE skill_executions (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id       UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  skill_id         VARCHAR(100) NOT NULL REFERENCES skills(skill_id),
  scene_category   VARCHAR(50),
  confidence_score FLOAT,
  execution_time_ms INTEGER,
  success          BOOLEAN DEFAULT TRUE,
  error_message    TEXT,
  created_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_skill_executions_session ON skill_executions(session_id);
CREATE INDEX idx_skill_executions_skill   ON skill_executions(skill_id);
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID (PK) | — |
| session_id | UUID (FK→sessions) | 关联会话 |
| skill_id | VARCHAR (FK→skills) | 执行的技能 |
| scene_category | VARCHAR(50) | 识别场景（workplace/family/personal） |
| confidence_score | FLOAT | 场景置信度 |
| execution_time_ms | INTEGER | 执行耗时（ms） |
| success | BOOLEAN, DEFAULT TRUE | 是否成功 |
| error_message | TEXT | 失败原因 |

---

#### `verification_codes` — 验证码表

```sql
CREATE TABLE verification_codes (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone      VARCHAR(11) NOT NULL,
  code       VARCHAR(6) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used       BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_verification_phone      ON verification_codes(phone);
CREATE INDEX idx_verification_expires_at ON verification_codes(expires_at);
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID (PK) | — |
| phone | VARCHAR(11), NOT NULL | 目标手机号 |
| code | VARCHAR(6), NOT NULL | 6位验证码 |
| expires_at | TIMESTAMPTZ, NOT NULL | 过期时间（默认 5 分钟，可配置） |
| used | BOOLEAN, DEFAULT FALSE | 是否已使用（使用后标记，不删除） |

---

#### `profiles` — 人物档案表

```sql
CREATE TABLE profiles (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name             VARCHAR(100) NOT NULL,
  relationship     VARCHAR(50) NOT NULL,
  photo_url        VARCHAR(500),
  notes            TEXT,
  audio_session_id UUID REFERENCES sessions(id) ON DELETE SET NULL,
  audio_segment_id VARCHAR(100),
  audio_start_time INTEGER,
  audio_end_time   INTEGER,
  audio_url        VARCHAR(500),
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_profiles_user_id ON profiles(user_id);
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | UUID (PK) | 档案 ID |
| user_id | UUID (FK→users), NOT NULL | 所属用户 |
| name | VARCHAR(100), NOT NULL | 人物名称 |
| relationship | VARCHAR(50), NOT NULL | 关系类型：`自己` / `死党` / `领导` / `同事` / `家人` 等 |
| photo_url | VARCHAR(500) | 头像 OSS URL（格式：`images/{uid}/profile_{pid}/0.png`） |
| notes | TEXT | 备注（如"性格强势，注重结果"） |
| audio_session_id | UUID (FK→sessions, ON DELETE SET NULL) | 关联的录音会话 |
| audio_segment_id | VARCHAR(100) | 音频片段 ID（如 `{session_id}_5_20`） |
| audio_start_time | INTEGER | 声纹片段开始时间（秒） |
| audio_end_time | INTEGER | 声纹片段结束时间（秒） |
| audio_url | VARCHAR(500) | 声纹音频片段 OSS URL |

---

#### `user_skill_preferences` — 用户技能偏好表

```sql
CREATE TABLE user_skill_preferences (
  id         SERIAL PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  skill_id   VARCHAR(100) NOT NULL,
  selected   BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, skill_id)
);
CREATE INDEX idx_user_skill_prefs_user ON user_skill_preferences(user_id);
```

| 字段 | 类型 | 说明 |
|---|---|---|
| id | SERIAL (PK) | 自增主键 |
| user_id | UUID (FK→users), NOT NULL | 用户 |
| skill_id | VARCHAR(100), NOT NULL | 技能 ID |
| selected | BOOLEAN, DEFAULT TRUE | 是否选中 |
| updated_at | TIMESTAMPTZ | 更新时间 |

**唯一约束**：`(user_id, skill_id)`

---

## 5. 后端服务设计

### 5.1 目录结构

```
0226new/
├── main.py                     # FastAPI 应用入口，核心分析流水线
├── requirements.txt            # Python 依赖
│
├── api/                        # 路由模块
│   ├── auth.py                 # 认证接口（发码/登录/用户信息）
│   ├── skills.py               # 技能管理接口（CRUD + 目录 + 偏好）
│   ├── profiles.py             # 档案管理接口
│   └── audio_segments.py       # 音频片段提取接口
│
├── auth/                       # 认证逻辑
│   ├── jwt_handler.py          # JWT 生成/验证/依赖注入
│   └── verification.py        # 验证码生成与校验
│
├── database/                   # 数据库层
│   ├── connection.py           # 异步引擎、连接池、会话工厂
│   ├── models.py               # SQLAlchemy ORM 模型定义
│   └── migrations/             # SQL 迁移脚本
│
├── skills/                     # 技能系统
│   ├── router.py               # 场景识别 + 技能匹配
│   ├── registry.py             # 技能注册/从数据库获取
│   ├── loader.py               # 从 SKILL.md 文件加载技能
│   ├── executor.py             # 技能执行（调用 Gemini）
│   ├── composer.py             # 多技能结果合并
│   ├── workplace_jungle/       # 职场丛林法则技能
│   ├── workplace_role/         # 角色方位分析技能
│   ├── workplace_scenario/     # 场景情境分析技能
│   ├── workplace_psychology/   # 心理风格分析技能
│   ├── workplace_career/       # 职业阶段分析技能
│   ├── workplace_capability/   # 能力维度分析技能
│   ├── emotion_recognition/    # 情绪识别技能
│   ├── depression_prevention/  # 防抑郁监控技能
│   ├── family_relationship/    # 亲密关系沟通技能
│   └── brainstorm/             # 头脑风暴协作技能
│
├── schemas/                    # Pydantic 模式
│   └── strategy_schemas.py     # 策略分析数据结构
│
├── services/                   # 业务服务
│   ├── memory_service.py       # Mem0 记忆服务
│   └── voiceprint_service.py   # 声纹匹配服务
│
└── utils/                      # 工具函数
    ├── audio_storage.py        # 音频本地存储/OSS/ffmpeg 切段
    └── user_preferences.py     # 用户偏好（图片风格等）
```

### 5.2 认证机制

- **登录方式**：手机号 + 6位验证码（开发环境固定返回 `123456`）
- **Token 类型**：JWT（HS256），有效期 168 小时（7天）
- **传输方式**：HTTP Bearer Token（`Authorization: Bearer <token>`）
- **用户缓存**：JWT 解码后，User 对象在内存中缓存 90 秒，减少重复数据库查询

```python
# JWT Payload 结构
{
  "sub": "<user_id_uuid>",
  "exp": <timestamp>,
  "iat": <timestamp>
}
```

### 5.3 异步分析任务架构

音频上传接口采用"立即返回 + 后台异步处理"模式：

```
POST /api/v1/audio/upload
  ↓ 1. 读取文件内容到内存
  ↓ 2. 创建 sessions 记录（status=analyzing）
  ↓ 3. 立即返回 {session_id, status: "analyzing"}
  ↓ 4. asyncio.create_task(analyze_audio_async)  ← 后台执行

analyze_audio_async()
  ↓ 持久化原音频（本地 or OSS）
  ↓ Call #1: Gemini 转录分析（超时 6 分钟）
  ↓ 声纹匹配 speaker_mapping
  ↓ 场景识别 classify_scene
  ↓ 技能匹配 match_skills
  ↓ 技能执行 execute_skill（per skill，并行/串行）
  ↓ 图片生成 generate_image_from_prompt（per visual_data）
  ↓ 保存 StrategyAnalysis
  ↓ 更新 sessions.status = "archived"
```

iOS 端通过**轮询** `GET /api/v1/tasks/sessions/{session_id}/status` 跟踪进度（首次等 8 秒，之后每 3 秒，最多 140 次 ≈ 7 分钟）。

---

## 6. API 接口文档

所有接口均以 `application/json` 格式传输，需要认证的接口在 Header 中携带：
```
Authorization: Bearer <jwt_token>
```

### 6.1 认证模块 `/api/v1/auth`

#### `POST /api/v1/auth/send-code` — 发送验证码

**请求体**：
```json
{"phone": "13800138000"}
```

**响应**：
```json
{
  "code": 200,
  "message": "验证码已发送",
  "data": {"phone": "13800138000", "code": "123456"}
}
```
> 开发环境（`VERIFICATION_CODE_MOCK=true`）响应中直接返回 code；生产环境 code 为 null。

---

#### `POST /api/v1/auth/login` — 登录（首次自动注册）

**请求体**：
```json
{"phone": "13800138000", "code": "123456"}
```

**响应**：
```json
{
  "code": 200,
  "message": "登录成功",
  "data": {
    "token": "<jwt_token>",
    "user_id": "<uuid>",
    "expires_in": 604800
  }
}
```

---

#### `GET /api/v1/auth/me` — 获取当前用户信息

**认证**：需要

**响应**：
```json
{
  "code": 200,
  "message": "获取成功",
  "data": {
    "user_id": "<uuid>",
    "phone": "138****8000",
    "created_at": "2026-01-08T00:00:00",
    "last_login_at": "2026-02-26T12:00:00"
  }
}
```

---

### 6.2 音频上传与分析

#### `POST /api/v1/audio/upload` — 上传音频并开始分析

**认证**：需要
**Content-Type**：`multipart/form-data`

**参数**：
- `file`：音频文件（.m4a / .mp3 / .wav，最大受 Nginx 限制，默认 200MB）
- `title`（可选）：自定义标题

**响应**：
```json
{
  "code": 200,
  "message": "上传成功",
  "data": {
    "session_id": "<uuid>",
    "audio_id": "<uuid>",
    "title": "录音 14:23",
    "status": "analyzing",
    "estimated_duration": 300,
    "created_at": "2026-02-26T14:23:00"
  }
}
```

---

#### `GET /api/v1/tasks/sessions/{session_id}/status` — 查询任务状态

**认证**：需要

**响应**：
```json
{
  "session_id": "<uuid>",
  "status": "analyzing",
  "progress": 0.6,
  "estimated_time_remaining": 120,
  "updated_at": "2026-02-26T14:25:00",
  "failure_reason": null,
  "analysis_stage": "strategy_executing",
  "analysis_stage_detail": {"skills_matched": 3, "skill_names": ["职场丛林法则"]}
}
```

---

#### `GET /api/v1/tasks/sessions` — 获取任务列表

**认证**：需要
**查询参数**：`page`（默认 1），`page_size`（默认 20），`status`，`date`

**响应**：
```json
{
  "sessions": [
    {
      "session_id": "<uuid>",
      "title": "和领导的周会",
      "start_time": "2026-02-26T14:00:00+08:00",
      "end_time": "2026-02-26T14:30:00+08:00",
      "duration": 1800,
      "tags": ["#PUA预警", "#职场"],
      "status": "archived",
      "emotion_score": 45,
      "speaker_count": 2,
      "summary": "会议中领导提出了加班要求...",
      "cover_image_url": "http://..."
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 42,
    "total_pages": 3,
    "has_more": true
  }
}
```

---

#### `GET /api/v1/tasks/sessions/{session_id}` — 获取任务详情

**认证**：需要

**响应**（完整字段）：
```json
{
  "session_id": "<uuid>",
  "title": "和领导的周会",
  "start_time": "2026-02-26T14:00:00",
  "end_time": "2026-02-26T14:30:00",
  "duration": 1800,
  "tags": ["#PUA预警"],
  "status": "archived",
  "error_message": null,
  "emotion_score": 45,
  "speaker_count": 2,
  "dialogues": [
    {"speaker": "Speaker_0", "content": "...", "tone": "...", "timestamp": "00:05", "is_me": false},
    {"speaker": "Speaker_1", "content": "...", "tone": "...", "timestamp": "00:15", "is_me": true}
  ],
  "risks": ["任务分配不公平", "职场 PUA 迹象"],
  "summary": "...",
  "speaker_mapping": {"Speaker_0": "<profile_id>", "Speaker_1": "<profile_id>"},
  "speaker_names": {"Speaker_0": "张总（领导）", "Speaker_1": "我（自己）"},
  "conversation_summary": "你和张总的一次项目汇报会议",
  "cover_image_url": "http://...",
  "created_at": "2026-02-26T14:00:00",
  "updated_at": "2026-02-26T14:35:00"
}
```

---

#### `GET /api/v1/tasks/sessions/{session_id}/strategy` — 获取策略分析结果

**认证**：需要

**响应**（v0.8 skill_cards 格式）：
```json
{
  "code": 200,
  "data": {
    "session_id": "<uuid>",
    "scene_category": "workplace",
    "scene_confidence": 0.95,
    "applied_skills": [{"skill_id": "workplace_role", "priority": 100}],
    "skill_cards": [
      {
        "skill_id": "workplace_role",
        "skill_name": "角色方位分析",
        "content_type": "strategy",
        "category": "workplace",
        "dimension": "role_position",
        "matched_sub_skill": "managing_up",
        "content": {
          "visual": [
            {
              "transcript_index": 3,
              "speaker": "Speaker_0",
              "image_prompt": "宫崎骏风格，办公室场景...",
              "emotion": "anxious",
              "subtext": "想要压住我的声音",
              "context": "汇报环节，领导打断",
              "my_inner": "我得更强硬一点",
              "other_inner": "这个下属需要管控",
              "image_url": "http://.../images/.../0.png"
            }
          ],
          "strategies": [
            {
              "id": "s1",
              "label": "向上管理",
              "emoji": "👔",
              "title": "高效汇报的5个技巧",
              "content": "1. 准备充分...\n2. 控制节奏..."
            }
          ]
        }
      },
      {
        "skill_id": "emotion_recognition",
        "skill_name": "情绪识别",
        "content_type": "emotion",
        "category": "personal",
        "dimension": "",
        "matched_sub_skill": "",
        "content": {
          "sigh_count": 2,
          "haha_count": 0,
          "mood_state": "焦虑",
          "mood_emoji": "😰",
          "char_count": 150
        }
      },
      {
        "skill_id": "depression_prevention",
        "skill_name": "防抑郁监控",
        "content_type": "mental_health",
        "category": "personal",
        "dimension": "",
        "matched_sub_skill": "",
        "content": {
          "defense_energy_pct": 35,
          "dominant_defense": "isolation",
          "status_assessment": "warning",
          "cognitive_triad": {
            "self":   {"status": "yellow", "reason": "对自己的评价偏低"},
            "world":  {"status": "red",    "reason": "感受到外部敌意"},
            "future": {"status": "yellow", "reason": "对未来缺乏信心"}
          },
          "insight": "针对性洞察...",
          "strategy": "建议策略...",
          "crisis_alert": false
        }
      }
    ],
    "visual_data": [],
    "strategies": []
  }
}
```

> **注意**：`visual_data` 与 `strategies` 为旧版字段，v0.8 后已合并进 `skill_cards[].content` 中。

---

#### `POST /api/v1/tasks/sessions/{session_id}/classify-scene` — 手动触发场景识别

**认证**：需要
**说明**：可独立触发场景识别（不含技能执行），用于调试或重新分类。

**响应**：
```json
{
  "code": 200,
  "data": {
    "scenes": [
      {"category": "workplace", "confidence": 0.95, "reasoning": "对话涉及项目汇报"},
      {"category": "family",   "confidence": 0.30, "reasoning": "提到了家庭安排"}
    ],
    "primary_scene": "workplace",
    "workplace_dimensions": [
      {
        "dimension": "role_position",
        "sub_skill": "managing_up",
        "sub_skill_name": "向上管理",
        "confidence": 0.9,
        "reasoning": "对话是向领导汇报工作"
      }
    ],
    "matched_skills": [
      {"skill_id": "workplace_role", "name": "角色方位分析", "priority": 100}
    ]
  }
}
```

---

#### `POST /api/v1/tasks/sessions/{session_id}/strategies` — 手动触发策略分析

**认证**：需要
**查询参数**：`force_regenerate=false`（是否强制重新生成），`image_style=ghibli`（图片风格）

**说明**：当已有分析结果时可调用此接口重新执行策略，或指定不同图片风格重新生成图片。

**响应**：与 GET /strategy 格式相同的完整策略数据。

---

#### `GET /api/v1/tasks/sessions/{session_id}/emotion-trend` — 获取情绪趋势

**认证**：需要
**查询参数**：`limit=30`（最多返回最近 N 次）

**响应**：
```json
{
  "code": 200,
  "data": {
    "points": [
      {
        "session_id": "<uuid>",
        "created_at": "2026-02-26T14:00:00",
        "mood_state": "焦虑",
        "mood_emoji": "😰",
        "sigh_count": 2,
        "haha_count": 0,
        "char_count": 150
      }
    ]
  }
}
```

---

### 6.3 技能模块 `/api/v1/skills`

#### `GET /api/v1/skills` — 获取技能列表

**认证**：需要
**查询参数**：`category`（可选），`enabled`（默认 true）

**响应**：`{"code": 200, "data": {"skills": [SkillResponse]}}`

---

#### `GET /api/v1/skills/catalog` — 获取技能目录（分类展开 + 用户选中状态）

**认证**：需要

**响应**：
```json
{
  "code": 200,
  "data": {
    "categories": [
      {
        "id": "workplace",
        "name": "职场",
        "icon": "briefcase.fill",
        "skills": [
          {
            "skill_id": "managing_up",
            "parent_skill_id": "workplace_role",
            "name": "向上管理",
            "description": "...",
            "cover_color": "#5E7C8B",
            "selected": true
          }
        ]
      }
    ]
  }
}
```

---

#### `GET /api/v1/skills/{skill_id}` — 获取技能详情

**认证**：需要
**查询参数**：`include_content=true`（包含 SKILL.md 完整内容）

---

#### `POST /api/v1/skills` — 创建技能（管理员）

#### `PUT /api/v1/skills/{skill_id}` — 更新技能

#### `POST /api/v1/skills/{skill_id}/reload` — 重新加载技能（热重载）

#### `GET /api/v1/skills/preferences` — 获取用户技能偏好

#### `PUT /api/v1/skills/preferences` — 更新用户技能偏好

```json
// PUT /api/v1/skills/preferences
{"selected_skills": ["managing_up", "conflict_resolution"]}
```

---

### 6.4 档案模块 `/api/v1/profiles`

#### `GET /api/v1/profiles` — 获取所有档案

**认证**：需要
**响应**：ProfileResponse 数组（带 60 秒内存缓存）

---

#### `POST /api/v1/profiles` — 创建档案

```json
{
  "name": "张总",
  "relationship": "领导",
  "photo_url": "http://...",
  "notes": "性格强势，注重结果",
  "audio_session_id": "<uuid>",
  "audio_segment_id": "<session>_0_15",
  "audio_start_time": 0,
  "audio_end_time": 15,
  "audio_url": "http://..."
}
```

#### `PUT /api/v1/profiles/{profile_id}` — 更新档案

#### `DELETE /api/v1/profiles/{profile_id}` — 删除档案

#### `POST /api/v1/profiles/upload-photo` — 上传档案头像到 OSS

---

### 6.5 音频片段模块

#### `GET /api/v1/tasks/sessions/{session_id}/audio-segments` — 获取音频片段列表

**响应**：按对话顺序返回所有片段（time range 来自 dialogues.timestamp）

---

#### `POST /api/v1/tasks/sessions/{session_id}/extract-segment` — 提取并上传音频片段

```json
{"start_time": 5.0, "end_time": 20.0, "speaker": "Speaker_0"}
```

**响应**：
```json
{
  "segment_id": "<uuid>_5_20",
  "audio_url": "http://oss.../audio/...",
  "duration": 15.0
}
```

---

### 6.6 图片服务

#### `GET /api/v1/images/{session_id}/{index}` — 获取 OSS 私有图片（认证代理）

**认证**：需要
后端从 OSS 读取 `images/{user_id}/{session_id}/{index}.png` 并以流式返回（二进制 PNG）。
若 OSS 未启用，则从本地磁盘返回。

#### `GET /api/v1/images/cleanup` — 清理过期图片

**认证**：需要（管理员）
**查询参数**：`days=7`（清理 N 天前的图片）

**响应**：
```json
{"code": 200, "data": {"deleted_count": 42}}
```

---

### 6.7 用户偏好

#### `PUT /api/v1/users/me/preferences` — 更新用户偏好（图片风格）

```json
{"image_style": "pixar"}
```

**支持的图片风格**（15种）：`ghibli` / `shinkai` / `pixar` / `cyberpunk` / `watercolor` / `ukiyoe` / `line_art` / `steampunk` / `pop_art` / `scandinavian` / `retro_manga` / `oil_painting` / `pixel` / `chinese_ink` / `storybook`

---

## 7. 技能系统设计

### 7.1 技能目录结构

每个技能是一个独立文件夹，包含 `SKILL.md` 文件：

```
skills/
└── workplace_jungle/
    └── SKILL.md        ← YAML frontmatter + Markdown 文档 + Prompt 模板
```

### 7.2 SKILL.md 结构

```markdown
---
name: 职场丛林法则
description: 适用于职场沟通的策略分析技能
category: workplace        # workplace / family / personal
priority: 100              # 数值越高越优先
version: "1.0.0"
enabled: true
keywords:                  # 用于旧版关键词匹配（现已由 LLM 路由替代）
  - "老板"
  - "同事"
scenarios:
  - "上下级沟通"
dimension: role_position   # 职场维度（仅 workplace 类技能）
sub_skills:                # 子技能列表（展示在技能目录）
  - id: managing_up
    name: 向上管理
    description: 与领导/上级的沟通策略
    cover_color: "#5E7C8B"
display_description: 识别职场话术潜台词，保护你的利益
cover_color: "#4A6572"
---

# 技能标题

## 技能概述
...

## Prompt模板
```prompt
角色：你是...
任务：分析以下对话...
输出格式：...
```
```

### 7.3 技能分类体系

| 一级分类 | 说明 | 父技能 ID（后端匹配用） |
|---|---|---|
| `workplace` | 职场 | workplace_role、workplace_scenario、workplace_psychology、workplace_career、workplace_capability、brainstorm、workplace_jungle（已停用） |
| `family` | 家庭 | family_relationship、education_communication |
| `personal` | 个人成长 | emotion_recognition、depression_prevention |

> **注意**：`brainstorm` 的数据库 `category` 字段为 `workplace`，在 iOS 技能目录中显示于「职场」分类下（非「个人成长」）。

### 7.4 职场场景多维度识别

Router Agent 通过单次 LLM 调用识别五个维度：

| 维度 | 技能 ID | 子技能示例 |
|---|---|---|
| `role_position` 角色方位分析 | `workplace_role` | managing_up/managing_down/peer_collaboration/external_communication |
| `scenario` 场景情境分析 | `workplace_scenario` | conflict_resolution/negotiation/presentation/small_talk/crisis_management |
| `psychology` 心理风格分析 | `workplace_psychology` | defensive/offensive/constructive/healing |
| `career_stage` 职业阶段分析 | `workplace_career` | rookie/core_manager/executive |
| `capability` 能力维度分析 | `workplace_capability` | logical_thinking/eq/influence |

### 7.5 技能匹配流程

```
对话转录(transcript)
    ↓
classify_scene()  ← 单次 Gemini LLM 调用
    发送 Prompt：
      - 识别 top-level scenes（workplace/family/other）及置信度
      - 识别 workplace_dimensions（role_position/scenario/psychology/career_stage/capability）
    返回 JSON：
      {
        "scenes": [{"category": "workplace", "confidence": 0.95, "reasoning": "..."}],
        "primary_scene": "workplace",
        "workplace_dimensions": [
          {"dimension": "role_position", "sub_skill": "managing_up",
           "sub_skill_name": "向上管理", "confidence": 0.9, "reasoning": "..."}
        ]
      }
    ↓ scenes[] + workplace_dimensions[]
    ↓
_supplement_scenes_by_participants()  ← 关键词兜底补充
    若 LLM 未识别到场景，按关键词追加（confidence=0.6）：
    - WORKPLACE_KEYWORDS: 同事、领导、老板、上级、下属、经理、总监、主管
    - FAMILY_KEYWORDS:    爸爸、妈妈、老婆、老公、孩子、儿子、女儿、家人
    ↓
match_skills()
    ├── workplace 场景 → 按 workplace_dimensions 匹配对应维度技能：
    │     role_position  → workplace_role
    │     scenario       → workplace_scenario
    │     psychology     → workplace_psychology
    │     career_stage   → workplace_career
    │     capability     → workplace_capability
    ├── family 场景 → 按 category=family 匹配
    ├── personal/other 场景 → 按 category=personal 匹配
    ├── 始终追加 emotion_recognition（所有对话）
    └── 条件追加 depression_prevention（危机词触发）
    ↓
技能去重（by skill_id） + 按 (priority DESC, confidence DESC) 排序
```

### 7.6 防抑郁监控触发规则

```python
# 强制触发（任意 speaker 出现）
危机词 = ["不想活", "想活了", "活不下去", "死了算了", "想死", "自杀"]

# 一般触发（用户话语(is_me=true) ≥50字 且命中）
一般词 = ["搞砸", "没用", "失败", "我不配", "废物", "总是", "绝对",
          "累", "焦虑", "抑郁", "没希望", "完蛋", "没救了", "没办法"]
```

### 7.7 skill_cards 字段详细格式

每次分析完成后，`strategy_analysis.skill_cards` 存储按技能分组的结果，iOS 客户端直接按此数组渲染 UI：

```json
[
  {
    "skill_id": "workplace_role",        // 技能 ID
    "skill_name": "角色方位分析",           // 技能名称
    "content_type": "strategy",          // "strategy"|"emotion"|"mental_health"
    "category": "workplace",             // "workplace"|"family"|"personal"
    "dimension": "role_position",        // 职场维度（非职场技能为空字符串）
    "matched_sub_skill": "managing_up",  // 匹配到的子技能 ID（无则为空字符串）
    "content": {
      // content_type="strategy" 时：
      "visual": [
        {
          "transcript_index": 3,
          "speaker": "Speaker_0",
          "image_prompt": "宫崎骏风格...",
          "emotion": "anxious",
          "subtext": "潜台词描述",
          "context": "场景/心理状态",
          "my_inner": "我的内心OS",
          "other_inner": "对方的内心OS",
          "image_url": "https://...0.png",     // OSS URL（优先）
          "image_base64": null                  // Base64（OSS 不可用时）
        }
      ],
      "strategies": [
        {
          "id": "s1",
          "label": "向上管理",
          "emoji": "👔",
          "title": "高效汇报的5个技巧",
          "content": "Markdown 格式策略内容..."
        }
      ]
    }
  },
  {
    "skill_id": "emotion_recognition",
    "skill_name": "情绪识别",
    "content_type": "emotion",           // 固定类型
    "category": "personal",
    "dimension": "",
    "matched_sub_skill": "",
    "content": {
      // content_type="emotion" 时：
      "sigh_count": 2,                   // 叹气次数（规则匹配：唉|哎|唉声叹气）
      "haha_count": 5,                   // 笑声次数（规则匹配：哈哈|呵呵|嘿哈）
      "mood_state": "焦虑",              // LLM 判定的情绪状态
      "mood_emoji": "😰",               // 对应 Emoji
      "char_count": 250                  // 用户发言总字数
    }
  },
  {
    "skill_id": "depression_prevention",
    "skill_name": "防抑郁监控",
    "content_type": "mental_health",     // 固定类型
    "category": "personal",
    "dimension": "",
    "matched_sub_skill": "",
    "content": {
      // content_type="mental_health" 时：
      "defense_energy_pct": 35,          // 防御机制强度（0-100）
      "dominant_defense": "isolation",   // 主要防御类型
      "status_assessment": "warning",    // "normal"|"warning"|"critical"
      "cognitive_triad": {
        "self":   {"status": "yellow", "reason": "对自己评价偏低"},
        "world":  {"status": "red",    "reason": "感受到外部敌意"},
        "future": {"status": "yellow", "reason": "对未来缺乏信心"}
      },
      "insight": "针对性心理洞察...",
      "strategy": "建议应对策略...",
      "crisis_alert": false              // true 时须立即提示用户
    }
  }
]
```

### 7.8 技能执行流程（execute_skill）

```
技能执行器 executor.py
    ↓
加载技能 prompt_template（优先从 DB，fallback SKILL.md）
    ↓
替换 Prompt 占位符：
  {transcript_json}   → JSON 序列化的对话转录
  {session_id}        → 会话 UUID
  {user_id}           → 用户 UUID
  {memory_context}    → Mem0 记忆上下文（若启用）
  {matched_sub_skill} → 子技能名称（如"向上管理"）
  {dimension}         → 维度名称（如"role_position"）
    ↓
调用 Gemini（gemini-3-flash-preview）
    ↓
解析响应 JSON（自动去除 ```json 代码块）
    ↓ 返回：
    {
      "skill_id": "...",
      "name": "...",
      "result": {
        "visual": [VisualData, ...],    // 5 个场景最多
        "strategies": [StrategyItem, ...]
      },
      "execution_time_ms": 1234,
      "success": true,
      "priority": 100,
      "confidence": 0.95
    }
```

**特殊技能的不同执行路径**：

| 技能 | 执行函数 | 输出字段 |
|---|---|---|
| `emotion_recognition` | `_execute_emotion_skill()` | `emotion_insight: {sigh_count, haha_count, mood_state, mood_emoji, char_count}` |
| `depression_prevention` | `_execute_depression_skill()` | `mental_health_insight: {defense_energy_pct, dominant_defense, status_assessment, cognitive_triad, insight, strategy, crisis_alert}` |
| 其他所有技能 | `_execute_strategy_skill()` | `result: {visual, strategies}` |

### 7.9 iOS 技能库 — 用户视角（技能目录）

iOS 技能库（`GET /api/v1/skills/catalog`）展示的是**子技能**，而非父技能名称。父技能（如 `workplace_role`）在后台用于 LLM 路由匹配，用户不可见；用户在 App「技能库」页面选择的是其下展开的子技能条目。

#### 技能目录完整列表（用户可见）

**职场（workplace）**

| 子技能 ID | 用户看到的名称 | 所属父技能 | 封面颜色 | 简介 |
|---|---|---|---|---|
| `managing_up` | 向上管理 | workplace_role | #FF6B6B | 与上级建立信任关系，有效汇报工作进展，争取资源支持 |
| `managing_down` | 向下管理 | workplace_role | #4ECDC4 | 有效领导团队，合理授权委派，激发下属动力与成长 |
| `peer_collaboration` | 横向协作 | workplace_role | #45B7D1 | 无权威影响力下推动跨部门合作，建立互利共赢的协作关系 |
| `external_communication` | 对外沟通 | workplace_role | #96CEB4 | 管理客户关系与外部合作，维护品牌形象与商业利益 |
| `conflict_resolution` | 冲突化解 | workplace_scenario | #E74C3C | 化解争端与矛盾，将对抗转为合作，维护职场关系 |
| `negotiation` | 谈判博弈 | workplace_scenario | #F39C12 | 掌握薪资、资源、条件的谈判技巧，争取最优结果 |
| `presentation` | 汇报展示 | workplace_scenario | #3498DB | 结构化表达与展示技巧，让汇报清晰有力、打动听众 |
| `small_talk` | 闲聊社交 | workplace_scenario | #2ECC71 | 职场破冰与社交技巧，建立人脉关系与社交资本 |
| `crisis_management` | 危机公关 | workplace_scenario | #9B59B6 | 危机应对与声誉修复，将损失降到最低并化危为机 |
| `defensive` | 防御技能 | workplace_psychology | #7F8C8D | 设定边界与自我保护，学会优雅地说不，守住底线 |
| `offensive` | 进攻技型 | workplace_psychology | #E67E22 | 主动争取与推动变革，有力量地挑战现状、驱动改变 |
| `constructive` | 建设技能 | workplace_psychology | #27AE60 | 以问题解决为导向，构建双赢方案，推动正和博弈 |
| `healing` | 治愈技能 | workplace_psychology | #FF9FF3 | 共情式倾听与情感支持，用温暖修复关系与信任 |
| `rookie` | 新人小白技能 | workplace_career | #74B9FF | 快速融入团队，建立专业信任，掌握职场生存基础法则 |
| `core_manager` | 骨干/中层技能 | workplace_career | #A29BFE | 高效执行与团队协调，管理资源分配与上下沟通 |
| `executive` | 高管/领袖技能 | workplace_career | #6C5CE7 | 战略决策与愿景沟通，塑造组织文化与领导影响力 |
| `logical_thinking` | 逻辑思维技能 | workplace_capability | #00B894 | 结构化思考与表达，用金字塔原理让沟通清晰有力 |
| `eq` | 情商提升 | workplace_capability | #FDCB6E | 提升情绪感知与社交技能，让沟通更有温度和分寸 |
| `influence` | 影响力提升 | workplace_capability | #E17055 | 提升说服力与感召力，让你的声音被听到、被跟随 |
| `brainstorm` | 头脑风暴协作 | brainstorm（无子技能） | #FD79A8 | 激发团队创意碰撞，高效协作讨论，产出突破性方案 |

**家庭（family）**

| 子技能 ID | 用户看到的名称 | 所属父技能 | 封面颜色 | 简介 |
|---|---|---|---|---|
| `family_relationship` | 亲密关系沟通 | family_relationship（无子技能） | #E84393 | 改善夫妻、亲子、家庭关系中的情感沟通与理解 |
| `education_communication` | 教育沟通引导 | education_communication（无子技能） | #00CEC9 | 科学引导孩子学习与成长，激发学习动机与自主性 |

**个人成长（personal）**

| 子技能 ID | 用户看到的名称 | 所属父技能 | 封面颜色 | 简介 |
|---|---|---|---|---|
| `emotion_recognition` | 情绪识别 | emotion_recognition（无子技能） | #FFEAA7 | 精准识别对话中的情绪信号，了解自身情绪状态变化 |
| `depression_prevention` | 防抑郁监控 | depression_prevention（无子技能） | #81ECEC | 通过语言模式早期识别心理健康风险，守护情绪安全 |

> **技术说明**：
> - 有 `sub_skills` 的父技能（workplace_role/scenario/psychology/career/capability）→ catalog 展开子技能，`parent_skill_id` = 父技能 ID
> - 无 `sub_skills` 的技能（brainstorm、family_relationship 等）→ 直接以自身为 catalog 条目，`parent_skill_id` = null
> - `workplace_jungle`（`enabled=false`）不出现在 catalog 中
> - 用户选中的是子技能 ID（如 `managing_up`），保存在 `user_skill_preferences` 表；LLM 路由匹配的是父技能 ID（如 `workplace_role`）

---

## 8. AI 分析流程

### 8.1 Call #1：语音转录与分析

**模型**：`gemini-3-flash-preview`（可通过 `GEMINI_FLASH_MODEL` 覆盖）

**输入**：音频文件（.m4a/.mp3/.wav，>18MB 自动分片后多段上传）

**Prompt 要点**（发给 Gemini 的指令摘要）：
```
- 转录音频，识别不同说话人（Speaker_0/Speaker_1）
- 为每句话标注：speaker、text、timestamp（MM:SS）、is_me（bool，需推断哪位是用户）
- 计算 mood_score（0-100，分越低越悲观）
- 统计 sigh_count（叹气/唉/哎）和 laugh_count（哈哈/呵呵）
- 生成 100-200字 summary
- 识别 risks（风险点列表，最多5条）
- 输出纯 JSON，不加任何额外说明
```

**输出 JSON**：
```json
{
  "mood_score": 45,
  "sigh_count": 3,
  "laugh_count": 1,
  "summary": "对话总结（100-200字）...",
  "transcript": [
    {"speaker": "Speaker_1", "text": "我今天的方案怎么样？", "timestamp": "00:01", "is_me": true},
    {"speaker": "Speaker_0", "text": "你自己觉得呢？",       "timestamp": "00:05", "is_me": false}
  ],
  "risks": ["权力不平衡", "隐性威胁", "回避性沟通"]
}
```

**处理结果存储**：
- `analysis_results.dialogues`：从 transcript 转换为 DialogueItem 格式（含 tone 字段）
- `analysis_results.call1_result`：完整原始 JSON
- `sessions.emotion_score`：= mood_score
- `sessions.speaker_count`：= len(distinct speakers)
- `sessions.tags`：由 risks 自动生成（如 `#PUA预警`、`#职场`）

### 8.2 大文件处理

- 文件 > 18MB → 自动用 pydub 分片为多个 ≤18MB 片段
- 每片段独立上传至 Gemini Files API（`GEMINI_UPLOAD_TIMEOUT=90s`）
- 在 Prompt 中说明片段时序关系（"这是第1段，共3段"），要求输出**全局时间戳**
- 分析完成后自动删除 Gemini 云端文件（节省配额）
- 超时控制：整体 Call #1 超时 6 分钟（`asyncio.wait_for` 360s）

### 8.3 声纹匹配

通过声纹特征将 `Speaker_0/Speaker_1` 与用户档案（Profile）绑定：

```
services/voiceprint_service.py
    ↓
1. 提取对话中各 Speaker 的音频片段（ffmpeg 切段）
2. 与用户档案（profiles）中保存的声纹片段 audio_url 进行比对
   - 发送两段音频给 Gemini，询问"是否为同一人"
3. 按置信度排序，高于阈值则绑定
4. 写入 analysis_results.speaker_mapping：
   {"Speaker_0": "<profile_id>", "Speaker_1": "<profile_id>"}
5. 生成 conversation_summary：
   "你（小明）和张总的一次项目汇报会议"
```

### 8.4 图片生成

**模型**：`gemini-2.5-flash-image`（4:3 宽高比，PNG 格式）

**流程**：
1. 技能执行输出 `image_prompt`（包含 emotion、subtext、context 等丰富场景描述）
2. 读取用户偏好的 `image_style`（默认 `ghibli`），从 `IMAGE_STYLE_MAP` 取风格前缀
3. 若 `speaker_mapping` 中存在档案，获取档案头像图片（左=用户，右=对方）作为 reference_images
4. 构造 Gemini 图片生成请求（文字 prompt + 可选参考图）
5. 请求失败时最多重试 3 次：
   - HTTP 429（配额限制）→ 指数退避（1s, 2s, 4s）
   - 其他错误 → 立即失败，返回 `image_url=null`
6. 生成图片上传 OSS：`images/{user_id}/{session_id}/{index}.png`
7. 将 URL 或 base64 写回 `visual_data[i].image_url` / `image_base64`

**支持的图片风格（15种）及风格前缀**：

| 枚举值 | 名称 | 风格描述 |
|---|---|---|
| `ghibli` | 宫崎骏 | Studio Ghibli animation style |
| `shinkai` | 新海诚 | Makoto Shinkai anime style |
| `pixar` | Pixar | Pixar 3D animation style |
| `cyberpunk` | 赛博朋克 | Cyberpunk neon city style |
| `watercolor` | 水彩画 | Watercolor painting style |
| `ukiyoe` | 浮世绘 | Japanese Ukiyo-e woodblock print |
| `line_art` | 线稿 | Black and white line art |
| `steampunk` | 蒸汽朋克 | Steampunk mechanical style |
| `pop_art` | 波普艺术 | Pop Art Andy Warhol style |
| `scandinavian` | 北欧插画 | Scandinavian flat illustration |
| `retro_manga` | 复古漫画 | Retro Japanese manga style |
| `oil_painting` | 油画 | Classic oil painting style |
| `pixel` | 像素风 | Pixel art 16-bit game style |
| `chinese_ink` | 水墨画 | Chinese ink wash painting |
| `storybook` | 故事书 | Children's storybook illustration |

---

## 9. iOS 客户端设计

### 9.1 项目结构

```
WorkSurvivalGuide.xcodeproj
└── WorkSurvivalGuide/
    ├── WorkSurvivalGuideApp.swift      # @main 入口
    ├── ContentView.swift               # 根视图（路由 Login/Main）
    ├── Models/
    │   ├── Task.swift                  # TaskItem, TaskListResponse, DialogueItem 等
    │   ├── Skill.swift                 # SkillCatalog, SkillCategory, SubSkill
    │   ├── Profile.swift               # Profile, AudioSegment 等
    │   ├── VisualData.swift            # VisualData, StrategyItem, SkillCard 等
    │   └── ImageStyle.swift            # ImageStyle 结构体 + 15种预设
    ├── Services/
    │   ├── NetworkManager.swift        # HTTP 请求管理（双节点路由，Alamofire）
    │   ├── AuthService.swift           # 登录/验证码/Token 管理
    │   ├── AuthManager.swift           # 全局认证状态 ObservableObject
    │   ├── KeychainManager.swift       # Token 安全存储（Security 框架）
    │   ├── AudioRecorderService.swift  # AVAudioRecorder 录音封装
    │   ├── ImageCacheManager.swift     # 图片内存+磁盘缓存（NSCache + SHA256）
    │   ├── DetailCacheManager.swift    # 任务详情/策略内存缓存（5分钟 TTL）
    │   ├── BluetoothDeviceManager.swift # 蓝牙耳机输入管理
    │   ├── GeminiAnalysisService.swift # Mock 模式直连 Gemini（开发用）
    │   ├── ProfileAudioPlayerService.swift # 档案声纹音频播放
    │   ├── MockNetworkService.swift    # 本地 Mock 数据（测试用）
    │   └── NetworkDiagnostics.swift    # 网络诊断工具
    ├── ViewModels/
    │   ├── AuthViewModel.swift         # 登录/验证码状态 + 60s 倒计时
    │   ├── RecordingViewModel.swift    # 录音控制 + 上传 + 轮询
    │   ├── TaskListViewModel.swift     # 任务列表 + 分页 + 摘要懒加载
    │   ├── ProfileViewModel.swift      # 档案管理 CRUD
    │   └── SkillsViewModel.swift       # 技能目录 + 偏好管理 + 防抖同步
    ├── Views/
    │   ├── LoginView.swift             # 手机号登录（+FocusState 键盘管理）
    │   ├── RegisterView.swift          # 注册（首次登录自动注册）
    │   ├── BottomNavView.swift         # 3-Tab 底部导航（磨砂玻璃背景）
    │   ├── TaskListView.swift          # 任务列表主页（按日期分组）
    │   ├── TaskCardView.swift          # 任务卡片（12阶段进度 overlay）
    │   ├── TaskDetailView.swift        # 任务详情页（5分钟缓存）
    │   ├── AnalysisStrategyView.swift  # 旧版策略展示
    │   ├── StrategyAnalysisView_Updated.swift  # 新版策略（skill_cards accordion）
    │   ├── SkillsView.swift            # 技能库页面
    │   ├── SkillDetailSheet.swift      # 技能详情弹窗
    │   ├── SkillCardView.swift         # 技能卡片组件
    │   ├── SkillCatalogCardView.swift  # 技能目录卡片
    │   ├── ProfileListView.swift       # 档案列表
    │   ├── ProfileEditView.swift       # 创建/编辑档案（照片+音频）
    │   ├── DialogueReviewView.swift    # 对话气泡回放
    │   ├── VisualMomentCarouselView.swift  # 策略图片轮播
    │   ├── FullScreenImageViewer.swift # 全屏图片查看器（捏合缩放）
    │   ├── ImageStylePickerSheet.swift # 15种图片风格选择器
    │   ├── ImageLoaderView.swift       # URL/Base64 图片加载+缓存
    │   ├── RemoteImageView.swift       # 异步远程图片组件
    │   ├── RecordingButtonView.swift   # 录音 FAB 按钮
    │   ├── AudioSelectionView.swift    # 对话时间轴片段选择
    │   ├── DeviceSelectionSheet.swift  # 蓝牙设备选择
    │   ├── TodayMoodView.swift         # 今日情绪卡片
    │   ├── EmotionTrendChartView.swift # 情绪趋势折线图
    │   └── QuotationMarkView.swift     # 引号装饰组件
    └── Shared/
        ├── AppConfig.swift             # 环境配置（双节点 URL + 开关）
        ├── AppFonts.swift              # 字体定义（Nunito + 系统回退）
        ├── DesignColors.swift          # 设计色值系统（AppColors.*）
        ├── ViewExtensions.swift        # SwiftUI 扩展（Color hex, 圆角等）
        └── PaperGridBackground.swift   # Canvas 绘制的方格纸背景
```

### 9.2 数据模型（Models）

#### Task.swift

```swift
enum TaskStatus: String, Codable {
    case recording  // 本地录音中
    case analyzing  // 服务端分析中
    case archived   // 分析完成
    case burned     // 已焚毁（软删除）
    case failed     // 分析失败
}

struct TaskItem: Codable, Identifiable {
    var id: String           // session_id
    var title: String
    var startTime: Date?
    var endTime: Date?
    var duration: Int?       // 秒
    var tags: [String]
    var status: TaskStatus
    var emotionScore: Int?   // 0-100
    var speakerCount: Int?
    var summary: String?
    var coverImageUrl: String?
    var progressDescription: String?  // 本地轮询状态文案
    // 计算属性：durationString, timeRangeString, refinedTitle, overlaySummary
}

struct TaskDetailResponse: Codable {
    var sessionId: String
    var title: String
    var startTime: Date?; var endTime: Date?; var duration: Int?
    var tags: [String]; var status: String
    var emotionScore: Int?; var speakerCount: Int?
    var dialogues: [DialogueItem]; var risks: [String]
    var summary: String?; var coverImageUrl: String?
    var speakerMapping: [String: String]?   // Speaker_0 → profile_id
    var speakerNames: [String: String]?     // Speaker_0 → "张总（领导）"
    var conversationSummary: String?
    var createdAt: Date; var updatedAt: Date
}

struct DialogueItem: Codable {
    var speaker: String; var content: String; var tone: String
    var timestamp: String?; var isMe: Bool?
}

struct TaskStatusResponse: Codable {
    var sessionId: String; var status: String
    var progress: Double?; var estimatedTimeRemaining: Int?
    var updatedAt: String?; var failureReason: String?
    var analysisStage: String?
    var analysisStageDetail: AnalysisStageDetail?
    var stageDisplayText: String  // 计算属性：阶段 → 中文文案
}
```

#### Profile.swift

```swift
struct Profile: Codable, Identifiable {
    var id: String; var name: String; var relationship: String
    var photoUrl: String?; var notes: String?
    var audioSessionId: String?; var audioSegmentId: String?
    var audioStartTime: Int?; var audioEndTime: Int?
    var audioUrl: String?
    var createdAt: String; var updatedAt: String
    // 方法：getAccessiblePhotoURL(baseURL:) → 将 OSS URL 转换为 API 代理 URL
}

struct AudioSegment: Codable, Identifiable {
    var id: String            // "{session_id}_{start}_{end}"
    var sessionId: String; var speaker: String
    var startTime: Double; var endTime: Double; var duration: Double
    var content: String       // 对应文本
    var audioUrl: String?
    var durationString: String  // 计算属性 MM:SS
}
```

#### Skill.swift

```swift
struct SkillCatalogItem: Codable, Identifiable, Hashable {
    var skillId: String; var parentSkillId: String?
    var name: String; var description: String?
    var coverColor: String?; var coverImage: String?; var videoUrl: String?
    var selected: Bool
}

struct SkillCategory: Codable, Identifiable {
    var id: String            // workplace / family / personal
    var name: String          // 职场 / 家庭 / 个人成长
    var icon: String          // SF Symbol name
    var skills: [SkillCatalogItem]
}
```

#### VisualData.swift

```swift
struct VisualData: Codable, Identifiable {
    var transcriptIndex: Int; var speaker: String
    var imagePrompt: String; var emotion: String
    var subtext: String; var context: String
    var myInner: String; var otherInner: String
    var imageUrl: String?; var imageBase64: String?
    // 方法：getAccessibleImageURL(baseURL:) → OSS URL 转 API 代理 URL
}

struct SkillCard: Codable, Identifiable {
    var skillId: String; var skillName: String
    var contentType: String   // "strategy" | "emotion" | "mental_health"
    var category: String?; var dimension: String?; var matchedSubSkill: String?
    var content: SkillCardContent?
    // 计算属性：accordionTitle, sceneCategory
}

struct SkillCardEmotionContent: Codable {
    var sighCount: Int; var hahaCount: Int
    var moodState: String; var moodEmoji: String; var charCount: Int
}

struct SkillCardMentalHealthContent: Codable {
    var defenseEnergyPct: Int; var dominantDefense: String
    var statusAssessment: String   // "normal" | "warning" | "critical"
    var cognitiveTriad: CognitiveTriad?
    var insight: String; var strategy: String; var crisisAlert: Bool
}

struct EmotionTrendPoint: Codable, Identifiable {
    var sessionId: String; var createdAt: String?
    var moodState: String; var moodEmoji: String
    var sighCount: Int; var hahaCount: Int; var charCount: Int
}
```

#### ImageStyle.swift

```swift
struct ImageStyle: Identifiable {
    var id: String           // "ghibli", "pixar" 等
    var name: String         // 中文名
    var nameEn: String       // 英文名
    var promptKeywords: String  // 传给 Gemini 的风格前缀
    var accentColor: Color
}

// 15 种预设风格（通过 ImageStylePresets.byId(_:) 查找）：
// ghibli, shinkai, pixar, cyberpunk, watercolor, ukiyoe,
// line_art, steampunk, pop_art, scandinavian, retro_manga,
// oil_painting, pixel, chinese_ink, storybook
```

### 9.3 服务层（Services）

#### NetworkManager — HTTP 双节点路由

```swift
class NetworkManager {                     // 单例
    var readBaseURL:  String  // http://123.57.29.111:8000/api/v1（北京）
    var writeBaseURL: String  // http://47.79.254.213/api/v1（新加坡）

    // 读接口（北京节点）
    func getTaskList(date:, status:, page:, pageSize:) async throws -> TaskListResponse
    func getTaskDetail(sessionId:) async throws -> TaskDetailResponse
    func getTaskStatus(sessionId:) async throws -> TaskStatusResponse
    func getStrategyAnalysis(sessionId:) async throws -> StrategyAnalysisResponse
    func getEmotionTrend() async throws -> EmotionTrendResponse
    func getProfilesList() async throws -> [Profile]
    func getSkillsCatalog() async throws -> SkillCatalogResponse

    // 写接口（新加坡节点）
    func uploadAudio(fileURL:, title:, onProgress:) async throws -> UploadResponse
    func createProfile(_ profile:) async throws -> Profile
    func updateProfile(_ profile:) async throws -> Profile
    func deleteProfile(profileId:) async throws
    func updateSkillPreferences(selectedSkills:) async throws

    // 工具
    func hasValidToken() -> Bool
}
```

#### AuthService — 认证

```swift
class AuthService {                        // 单例
    func sendVerificationCode(phone:) async throws -> SendCodeResponse
    func login(phone:, code:) async throws -> LoginResponse
    // 成功后自动调用 KeychainManager.saveToken() + saveUserID()
    func getCurrentUser() async throws -> UserInfo
    func logout()
}
```

#### KeychainManager — 安全存储

```swift
class KeychainManager {                    // 单例，使用 Security 框架
    // Key prefix: "com.worksurvivalguide.auth"
    func saveToken(_ token: String)
    func getToken() -> String?
    func deleteToken()
    func saveUserID(_ userID: String)
    func getUserID() -> String?
    func clearAll()
    func isLoggedIn() -> Bool
}
```

#### ImageCacheManager — 图片缓存

```swift
class ImageCacheManager {                  // 单例
    // 内存：NSCache（100条 / 50MB 上限）
    // 磁盘：Library/Caches/ImageCache，7天 TTL，SHA256 文件名
    func image(for urlString: String) -> UIImage?
    func image(forBase64 base64: String) -> UIImage?
    func cache(_ image: UIImage, for urlString: String)
    func cache(_ image: UIImage, forBase64 base64: String)
}
```

#### DetailCacheManager — 详情缓存

```swift
class DetailCacheManager {                 // 单例，内存缓存，5分钟 TTL
    func getCachedDetail(sessionId:) -> TaskDetailResponse?
    func cacheDetail(_:for sessionId:)
    func getCachedStrategy(sessionId:) -> StrategyAnalysisResponse?
    func cacheStrategy(_:for sessionId:)
    func isLoadingDetail(for sessionId:) -> Bool
    func isLoadingStrategy(for sessionId:) -> Bool
    func clearCache(for sessionId:)
    func clearAllCache()
    func clearExpiredCache()
}
```

#### AudioRecorderService — 录音

```swift
class AudioRecorderService: NSObject, ObservableObject {
    @Published var isRecording: Bool
    @Published var recordingTime: TimeInterval

    func startRecording()   // 申请麦克风权限 → AVAudioRecorder → .m4a 格式
    func stopRecording() -> URL?
    func cancelRecording()  // 删除临时文件
    var formattedTime: String  // MM:SS
    // 支持蓝牙输入：优先使用 BluetoothDeviceManager.preferredInputForRecording()
}
```

#### BluetoothDeviceManager — 蓝牙输入

```swift
class BluetoothDeviceManager: ObservableObject {
    @Published var selectedInputId: String?
    @Published var isBluetoothConnected: Bool
    @Published var availableBluetoothInputs: [AVAudioSessionPortDescription]

    func refreshInputs()    // 查询 AVAudioSession 可用蓝牙设备
    func selectInput(_ port: AVAudioSessionPortDescription?)
    func preferredInputForRecording() -> AVAudioSessionPortDescription?
    // 通过 AVAudioSession.routeChangeNotification 监听设备变化
    // 选择持久化到 UserDefaults
}
```

### 9.4 视图模型（ViewModels）

#### AuthViewModel

```swift
class AuthViewModel: ObservableObject {    // @MainActor
    @Published var phone: String           // 11位手机号
    @Published var code: String            // 6位验证码
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var showError: Bool
    @Published var countdown: Int          // 倒计时（0=可重发）
    @Published var canSendCode: Bool

    func sendCode()     // 验证手机号格式 → AuthService.sendVerificationCode()
    func login()        // 验证码非空 → AuthService.login() → AuthManager.loginSuccess()
    func startCountdown()  // 60秒定时器，每秒 -1
}
```

#### RecordingViewModel

```swift
class RecordingViewModel: ObservableObject {
    @Published var isRecording: Bool
    @Published var recordingTime: TimeInterval
    @Published var isUploading: Bool
    @Published var uploadProgress: Double       // 0.0-1.0
    @Published var uploadPhaseDescription: String

    func startRecording()
    // 1. AudioRecorderService.startRecording()
    // 2. 发布 NotificationCenter.NewTaskCreated（本地临时卡片）

    func stopRecordingAndUpload()
    // 1. AudioRecorderService.stopRecording() → audioURL
    // 2. NetworkManager.uploadAudio(onProgress:) → session_id
    // 3. 发布 TaskDeleted（删除临时卡片）+ NewTaskCreated（服务端卡片）
    // 4. startPollingStatus(sessionId)

    func uploadLocalFile(_ fileURL: URL)   // 从文件选择器导入音频

    func startPollingStatus(_ sessionId: String)
    // 首次等 8s，之后每 3s，最多 140 次（≈7分钟）
    // strategy_done/completed → getTaskDetail → 发布 TaskAnalysisCompleted
    // failed → 发布 TaskAnalysisFailed
    // 超时 → 发布 TaskAnalysisTimeout
}
```

#### TaskListViewModel

```swift
class TaskListViewModel: ObservableObject { // 单例
    @Published var tasks: [TaskItem]
    @Published var isLoading: Bool
    @Published var errorMessage: String?

    func loadTasks(date:, forceRefresh:)   // 分页加载，去重合并
    func refreshTasks()
    func refreshTasksAsync()               // 适配 pullToRefresh
    func addNewTask(_ task: TaskItem)      // 插入列表顶部
    func updateTask(_ task: TaskItem)      // 全字段更新
    func updateTaskStatus(_ task: TaskItem)
    func updateTaskProgress(taskId:, progressDescription:)
    func updateTaskSummary(taskId:, summary:)
    func deleteTask(taskId:)
    var groupedTasks: [String: [TaskItem]] // 按日期字符串分组
    func groupTitle(for dateString:) -> String  // "今天"/"昨天"/日期
    func loadMissingSummaries()  // 后台为无摘要的 archived 任务加载详情（最多5并发）
}
```

#### SkillsViewModel

```swift
class SkillsViewModel: ObservableObject {  // 单例
    @Published var categories: [SkillCategory]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var selectedSkillForDetail: SkillCatalogItem?
    @Published var selectedSkills: Set<String>

    func loadCatalog(forceRefresh:)
    func refreshCatalog()
    func toggleSkill(_ skillId: String)      // 切换选中 + 防抖同步服务端
    func isSkillSelected(_ skillId: String) -> Bool
    func showDetail(_ skill: SkillCatalogItem)
    private func syncPreferencesToServer()   // 防抖 500ms 后发送 PUT /skills/preferences
}
```

### 9.5 主要视图（Views）

#### 导航结构

```
ContentView
├── [未登录] LoginView / RegisterView
└── [已登录] BottomNavView
    ├── Tab 1: TaskListView (碎片)
    │   ├── TaskCardView（列表项，按日期分组）
    │   ├── RecordingButtonView（FAB 悬浮录音按钮）
    │   └── TaskDetailView（NavigationLink 跳转）
    │       ├── DialogueReviewView（对话气泡）
    │       └── StrategyAnalysisView_Updated（策略/技能卡片）
    │           ├── VisualMomentCarouselView（图片轮播）
    │           └── FullScreenImageViewer（全屏查看）
    ├── Tab 2: SkillsView (技能库)
    │   ├── SkillCatalogCardView（分类卡片）
    │   └── SkillDetailSheet（详情弹窗）
    └── Tab 3: ProfileListView (档案)
        └── ProfileEditView（创建/编辑）
            └── AudioSelectionView（声纹片段选择）
```

#### StrategyAnalysisView_Updated（核心 UI，~51KB）

新版策略展示视图，按 `skill_cards` 数组渲染：

- **场景 Tab** 切换：职场 / 家庭 / 个人成长
- **Accordion 面板**：每个 SkillCard 一个可折叠面板
  - `content_type = "strategy"` → 图片轮播（VisualMomentCarouselView）+ 策略列表
  - `content_type = "emotion"` → 情绪统计卡（mood_emoji / sigh_count / haha_count / char_count）
  - `content_type = "mental_health"` → 防御能量环 + 认知三角灯（red/yellow/green）+ crisis_alert 弹窗
- **图片风格按钮** → ImageStylePickerSheet → 触发重新生成图片
- **图片点击** → FullScreenImageViewer（支持捏合缩放、滑动切换、保存到相册）

#### TaskCardView — 进度 Overlay（12阶段）

```
录音中   → 红色录音指示动画
上传中   → 上传进度条
upload_done → 0%
transcribing → 20%
matching_profiles → 35%
strategy_scene → 45%
strategy_matching → 55%
strategy_matched_n → 65%
strategy_executing → 75%
strategy_images → 85%
strategy_done/oss_upload → 95%
archived → 封面图 + 情绪分数 + 标签
failed → 错误图标
```

### 9.6 双节点路由策略

```swift
// AppConfig.swift
var readBaseURL:  String { "http://123.57.29.111:8000/api/v1" }  // 北京（读）
var writeBaseURL: String { "http://47.79.254.213/api/v1" }        // 新加坡（写）

// NetworkManager 路由规则
// → 新加坡（写节点）：
//     POST /audio/upload
//     POST /auth/send-code, /auth/login
//     POST/PUT/DELETE /profiles
//     PUT /skills/preferences
//     PUT /users/me/preferences
//     POST /sessions/{id}/extract-segment
//
// → 北京（读节点）：
//     GET /tasks/sessions（列表/详情/状态/策略）
//     GET /skills, /skills/catalog
//     GET /profiles
//     GET /images/{sid}/{idx}
//     GET /auth/me
//     GET /galaxy/overview
//     GET /tasks/emotion-trend
```

### 9.7 认证流程

```
App 启动
  ↓
AuthManager.checkLoginStatus()
  ├── KeychainManager.isLoggedIn() = true → 进入主界面
  └── false → 显示 LoginView
                ↓ 手机号输入 → AuthViewModel.sendCode()
                              → POST /auth/send-code（新加坡）
                ↓ 验证码输入 → AuthViewModel.login()
                              → POST /auth/login（新加坡）
                              → KeychainManager.saveToken() + saveUserID()
                              → AuthManager.loginSuccess() → isLoggedIn = true
                ↓ 进入主界面
```

### 9.8 录音与上传流程

```
RecordingButtonView（点击 FAB）
  ↓ RecordingViewModel.startRecording()
    ├── AudioRecorderService.startRecording()
    │   ├── 检查蓝牙设备（BluetoothDeviceManager.preferredInputForRecording()）
    │   └── AVAudioRecorder → Documents/recording_{uuid}.m4a
    └── NotificationCenter.post(.NewTaskCreated, 本地临时卡片)
        → TaskListViewModel.addNewTask()

  ↓ 再次点击 → RecordingViewModel.stopRecordingAndUpload()
    ├── AudioRecorderService.stopRecording() → audioURL
    └── NetworkManager.uploadAudio(fileURL, onProgress:)
          ↓ Alamofire multipart/form-data POST /api/v1/audio/upload（新加坡）
          ↓ 收到 {session_id}
          ↓ NotificationCenter.post(.TaskDeleted, 临时卡片 ID)
          ↓ NotificationCenter.post(.NewTaskCreated, 服务端卡片)
          ↓ startPollingStatus(sessionId)
              ↓ 首次等待 8s，之后每 3s
              ↓ GET /api/v1/tasks/sessions/{id}/status（北京）
              ↓ 最多 140 次（≈7分钟超时）
              ↓ strategy_done / archived
                  → getTaskDetail()
                  → NotificationCenter.post(.TaskAnalysisCompleted)
                  → TaskListViewModel.updateTask()
```

### 9.9 状态管理（NotificationCenter）

| 通知名称 | 发布者 | 接收者 | 携带数据 |
|---|---|---|---|
| `NewTaskCreated` | RecordingViewModel | TaskListViewModel | `TaskItem` |
| `TaskStatusUpdated` | RecordingViewModel | TaskListViewModel | `TaskItem` |
| `TaskProgressUpdated` | RecordingViewModel | TaskListViewModel, TaskCardView | `{taskId, progressDescription}` |
| `TaskSummaryAvailable` | RecordingViewModel | TaskCardView | `{taskId, summary}` |
| `TaskAnalysisCompleted` | RecordingViewModel | TaskListViewModel | `TaskItem` |
| `TaskAnalysisFailed` | RecordingViewModel | TaskListView | `{message}` |
| `TaskAnalysisTimeout` | RecordingViewModel | TaskListView | `{message}` |
| `TaskDeleted` | RecordingViewModel | TaskListViewModel | `taskId` |

### 9.10 图片加载策略

```
ImageLoaderView（URL 或 Base64 输入）
  ↓
1. 检查内存缓存（NSCache，100条 / 50MB）
2. 检查磁盘缓存（Library/Caches/ImageCache，7天 TTL）
3. 请求 GET /api/v1/images/{session_id}/{index}（JWT Bearer，北京节点）
   或 直接渲染 Base64 string
4. 写入内存 + 磁盘缓存（SHA256 文件名）
```

**图片 URL 转换逻辑**（`getAccessibleImageURL`）：
```
OSS URL (https://oss.../images/uid/sid/0.png)
  ↓
API 代理 URL (http://123.57.29.111:8000/api/v1/images/sid/0?t=timestamp)
  带 JWT Bearer 认证头
```

### 9.11 任务状态 UI 映射

| `status` | `analysis_stage` | 卡片 overlay 文案 | 进度 % |
|---|---|---|---|
| analyzing | upload_done | 上传完成 | 10% |
| analyzing | transcribing | 转写音频… | 25% |
| analyzing | matching_profiles | 匹配档案… | 40% |
| analyzing | strategy_scene | 识别场景… | 50% |
| analyzing | strategy_matching | 匹配技能… | 60% |
| analyzing | strategy_matched_n | 匹配了N个技能 | 65% |
| analyzing | strategy_executing | 技能加工中… | 75% |
| analyzing | strategy_images | 生成图片中… | 88% |
| analyzing | strategy_done | 策略就绪 | 95% |
| archived | — | 显示封面图+情绪分数 | 100% |
| failed | — | 显示错误信息+重试 | — |

### 9.12 架构模式

**MVVM + Singleton Services + NotificationCenter**

```
┌─────────────────────────────────────────────────────────┐
│  Views (SwiftUI)                                        │
│  @ObservedObject / @StateObject → ViewModel             │
│  @EnvironmentObject → AuthManager                       │
└───────────────────────┬─────────────────────────────────┘
                        │ @Published 驱动
┌───────────────────────▼─────────────────────────────────┐
│  ViewModels (@MainActor, ObservableObject)               │
│  TaskListViewModel, RecordingViewModel,                 │
│  AuthViewModel, ProfileViewModel, SkillsViewModel       │
└───────────────────────┬─────────────────────────────────┘
                        │ async/await
┌───────────────────────▼─────────────────────────────────┐
│  Services (Singletons)                                   │
│  NetworkManager → Alamofire → API                       │
│  AuthService → KeychainManager                          │
│  AudioRecorderService → AVAudioRecorder                 │
│  ImageCacheManager (NSCache + Disk)                     │
│  DetailCacheManager (Memory, 5min TTL)                  │
│  BluetoothDeviceManager → AVAudioSession                │
└─────────────────────────────────────────────────────────┘

NotificationCenter（跨层级松耦合通信）
  RecordingViewModel ──[post]──▶ TaskListViewModel
                              ▶ TaskListView
                              ▶ TaskCardView
```

**单例列表**（所有 `.shared` 访问）：
`NetworkManager` · `AuthManager` · `AuthService` · `KeychainManager` · `ImageCacheManager` · `DetailCacheManager` · `BluetoothDeviceManager` · `TaskListViewModel` · `ProfileViewModel` · `SkillsViewModel` · `GeminiAnalysisService` · `NetworkDiagnostics` · `MockNetworkService` · `ProfileAudioPlayerService`

### 9.13 Shared 配置

#### AppConfig

```swift
// 双节点 URL
var readBaseURL:  "http://123.57.29.111:8000/api/v1"  // 北京
var writeBaseURL: "http://47.79.254.213/api/v1"        // 新加坡

// 开关
var useMockData: Bool    // true = 使用 MockNetworkService（离线测试）
var useBeijingRead: Bool // 区域故障切换
```

#### AppFonts — 字体规范

| 用途 | 字体 | 大小 | 粗细 |
|---|---|---|---|
| headerTitle | Nunito | 24pt | Bold |
| cardTitle | Nunito | 17pt | SemiBold |
| time | Nunito | 13pt | Regular |
| bodyText | Nunito | 15pt | Regular |
| bottomNav | Nunito | 11pt | Medium |
| caption | System | 12pt | Regular |

#### DesignColors — 色彩系统

| Token | 用途 |
|---|---|
| `AppColors.background` | 主背景色 |
| `AppColors.cardBackground` | 卡片填充色 |
| `AppColors.primaryText` | 主文字色 |
| `AppColors.secondaryText` | 次级文字 |
| `AppColors.headerText` | 标题文字 |
| `AppColors.border` | 边框颜色 |
| `AppColors.BottomNav.active` | 底部导航激活色 |
| `AppColors.BottomNav.inactive` | 底部导航未激活色 |

`Color(hex: "#RRGGBB")` 扩展支持十六进制颜色字面量。

---

## 10. 部署架构

### 10.1 服务端部署

```
/home/<user>/
└── 0226new/                    # 项目根目录
    ├── main.py
    ├── .env                    # 环境变量（不提交 Git）
    └── data/
        └── audio/
            └── sessions/       # 原音频本地存储
                └── <session_id>.m4a

# 进程管理
systemd → gemini-audio.service
  ExecStart: uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
  WorkingDirectory: /home/.../0226new
  Restart: always
```

### 10.2 Nginx 配置要点

```nginx
# /etc/nginx/sites-enabled/gemini-audio
server {
    listen 80;
    client_max_body_size 200M;

    # 主应用反向代理
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }

    # Gemini API 反向代理（解决中国服务器无法直连 Google）
    location /secret-channel/ {
        proxy_pass https://generativelanguage.googleapis.com/;
        proxy_ssl_server_name on;
    }
}
```

### 10.3 OSS 目录结构

```
bucket/
├── images/
│   └── {user_id}/
│       ├── {session_id}/
│       │   ├── 0.png           # 第1张策略图
│       │   └── 1.png           # 第2张策略图
│       └── profile_{profile_id}/
│           └── 0.png           # 档案头像
└── sessions/
    └── {user_id}/
        └── {session_id}/
            └── original.m4a   # 原音频（启用 USE_OSS_FOR_ORIGINAL_AUDIO 时）
```

---

## 11. 环境变量配置

```env
# ===== 数据库 =====
DATABASE_URL=postgresql+asyncpg://user:password@host:5432/dbname
DATABASE_SSL=true                       # 启用 SSL（阿里云 RDS 需要）
DATABASE_CA_CERT=~/rds-ca.pem           # RDS CA 证书路径（可选）
USER_CACHE_TTL=90                       # 用户查询缓存 TTL（秒），默认 90

# ===== Gemini AI =====
GEMINI_API_KEY=AIza...                  # Google Gemini API Key（必填）
GEMINI_FLASH_MODEL=gemini-3-flash-preview  # 分析/场景识别模型（转录+策略）
USE_PROXY=true                          # 是否启用 Nginx 反向代理
PROXY_URL=http://47.79.254.213/secret-channel
PROXY_FORCE_LOCALHOST=true              # 代理与应用同机时设 true（使用 127.0.0.1）
GEMINI_FILE_UPLOAD_NO_PROXY=false       # 文件上传是否绕过代理（true=直连 Google）
GEMINI_UPLOAD_TIMEOUT=90                # Gemini 文件上传超时（秒），默认 90
FFPROBE_TIMEOUT=120                     # ffprobe 探测音频时长超时（秒），默认 120

# ===== 阿里云 OSS =====
USE_OSS=true                            # 是否使用 OSS 存储图片/音频
OSS_ACCESS_KEY_ID=...
OSS_ACCESS_KEY_SECRET=...
OSS_ENDPOINT=oss-cn-hangzhou.aliyuncs.com
OSS_BUCKET_NAME=my-bucket
OSS_CDN_DOMAIN=                         # CDN 域名（可选，填写后图片 URL 使用此域名）
USE_OSS_FOR_ORIGINAL_AUDIO=false        # 原音频是否上传 OSS（默认 false，存本地）

# ===== 认证 =====
JWT_SECRET_KEY=change-this-in-production  # JWT 签名密钥（生产环境必须修改）
JWT_ALGORITHM=HS256                     # 签名算法
JWT_EXPIRATION_HOURS=168                # Token 有效期（默认 168 = 7天）
VERIFICATION_CODE_MOCK=true             # 开发模式：返回 mock 验证码
VERIFICATION_CODE_MOCK_VALUE=123456     # Mock 验证码值
VERIFICATION_CODE_EXPIRY_MINUTES=5      # 验证码有效期（分钟），默认 5

# ===== 服务 =====
API_PUBLIC_URL=http://47.79.254.213     # 对外 URL 前缀（图片/音频 URL 生成用）
AUDIO_STORAGE_DIR=data/audio/sessions  # 原音频本地存储目录
AUDIO_SEGMENTS_DIR=data/audio/segments # 音频片段本地目录

# ===== 记忆系统（v0.6+，可选）=====
# 见 mem0ai 文档，需配置 Qdrant 向量库和（可选）Kuzu 知识图谱
GEMINI_EMBEDDING_MODEL=models/gemini-embedding-001  # 向量嵌入模型
GEMINI_EMBEDDING_DIM=1536                           # 嵌入向量维度
```

**完整环境变量参考表**：

| 变量 | 默认值 | 类型 | 说明 |
|---|---|---|---|
| `DATABASE_URL` | postgresql+asyncpg://localhost:5432/gemini_audio_db | str | PostgreSQL 异步连接串 |
| `DATABASE_SSL` | false | bool | 启用 SSL（阿里云 RDS 必须 true） |
| `DATABASE_CA_CERT` | ~ | str | CA 证书路径 |
| `USER_CACHE_TTL` | 90 | int | 用户对象内存缓存 TTL（秒） |
| `GEMINI_API_KEY` | （必填） | str | Google Gemini API 密钥 |
| `GEMINI_FLASH_MODEL` | gemini-3-flash-preview | str | 转录与策略分析模型 |
| `USE_PROXY` | true | bool | 是否通过 Nginx 反向代理访问 Gemini |
| `PROXY_URL` | http://127.0.0.1/secret-channel | str | 代理地址 |
| `PROXY_FORCE_LOCALHOST` | true | bool | 强制使用 127.0.0.1 替换代理中的域名 |
| `GEMINI_FILE_UPLOAD_NO_PROXY` | false | bool | 文件上传是否绕过代理直连 Google |
| `GEMINI_UPLOAD_TIMEOUT` | 90 | int | 单次文件上传超时（秒） |
| `FFPROBE_TIMEOUT` | 120 | int | ffprobe 命令超时（秒） |
| `JWT_SECRET_KEY` | your-secret-key-here | str | **生产必须修改** |
| `JWT_ALGORITHM` | HS256 | str | JWT 签名算法 |
| `JWT_EXPIRATION_HOURS` | 168 | int | Token 有效期（小时） |
| `VERIFICATION_CODE_MOCK` | true | bool | 开发模式：不发短信，code 直接返回 |
| `VERIFICATION_CODE_MOCK_VALUE` | 123456 | str | Mock 验证码 |
| `VERIFICATION_CODE_EXPIRY_MINUTES` | 5 | int | 验证码有效期（分钟） |
| `USE_OSS` | true | bool | 启用阿里云 OSS |
| `OSS_ACCESS_KEY_ID` | （必填） | str | 阿里云 AccessKey ID |
| `OSS_ACCESS_KEY_SECRET` | （必填） | str | 阿里云 AccessKey Secret |
| `OSS_ENDPOINT` | oss-cn-hangzhou.aliyuncs.com | str | OSS 地域 Endpoint |
| `OSS_BUCKET_NAME` | （必填） | str | Bucket 名称 |
| `OSS_CDN_DOMAIN` | （空） | str | 自定义 CDN 域名（可选） |
| `USE_OSS_FOR_ORIGINAL_AUDIO` | false | bool | 原音频是否也上传 OSS |
| `API_PUBLIC_URL` | http://47.79.254.213 | str | 对外服务根 URL |
| `AUDIO_STORAGE_DIR` | data/audio/sessions | str | 原音频本地存储目录 |
| `AUDIO_SEGMENTS_DIR` | data/audio/segments | str | 片段本地存储目录 |
| `GEMINI_EMBEDDING_MODEL` | models/gemini-embedding-001 | str | Mem0 嵌入模型 |
| `GEMINI_EMBEDDING_DIM` | 1536 | int | 嵌入向量维度 |

---

## 12. Pydantic 数据模型

### 12.1 对话与转录模型

```python
class TranscriptItem(BaseModel):
    speaker: str           # "Speaker_0" 或 "Speaker_1"
    text: str              # 发言内容
    timestamp: Optional[str] = None  # "MM:SS" 格式
    is_me: bool            # 是否是用户本人

class DialogueItem(BaseModel):
    speaker: str           # "Speaker_0" / 人物名称（声纹匹配后替换）
    content: str           # 对话内容
    tone: str              # 语气描述（如"强硬"、"委婉"）
    timestamp: Optional[str] = None
    is_me: Optional[bool] = False
```

### 12.2 策略分析模型

```python
class VisualData(BaseModel):
    transcript_index: int  # 对应转录中第 N 条对话
    speaker: str           # 该场景的主要说话人
    image_prompt: str      # 图片生成详细描述（含场景/情绪/人物关系）
    emotion: str           # 情绪标签（anxious/excited/defensive/etc.）
    subtext: str           # 话语潜台词
    context: str           # 场景或心理状态背景
    my_inner: str          # 用户的内心独白
    other_inner: str       # 对方的内心独白
    image_url: Optional[str] = None     # OSS 图片 URL（优先）
    image_base64: Optional[str] = None  # Base64 PNG（OSS 不可用时）

class StrategyItem(BaseModel):
    id: str                # 策略 ID（如 "s1"）
    label: str             # 标签（如 "向上管理"）
    emoji: str             # 对应表情符号
    title: str             # 策略标题
    content: str           # Markdown 格式策略内容

class Call2Response(BaseModel):
    visual: List[VisualData]
    strategies: List[StrategyItem]
```

### 12.3 Call #1 响应模型

```python
class Call1Response(BaseModel):
    mood_score: int              # 0-100
    sigh_count: int              # 叹气次数
    laugh_count: int             # 笑声次数
    summary: str                 # 对话总结
    transcript: List[TranscriptItem]
    risks: List[str]             # 风险点列表
```

### 12.4 技能相关模型

```python
class SkillResponse(BaseModel):
    skill_id: str
    name: str
    description: Optional[str]
    category: str
    priority: int
    enabled: bool
    version: Optional[str]
    metadata: Optional[dict]
    # 仅在 include_content=true 时返回：
    content: Optional[str]       # SKILL.md 完整内容
    prompt_template: Optional[str]

class SkillCard(BaseModel):
    skill_id: str
    skill_name: str
    content_type: str            # "strategy" | "emotion" | "mental_health"
    category: str
    dimension: str               # 职场维度（非职场技能为空字符串）
    matched_sub_skill: str       # 匹配子技能 ID
    content: dict                # 根据 content_type 不同结构不同
```

### 12.5 音频分段模型

```python
class AudioSegment(BaseModel):
    id: str                      # "{session_id}_{start}_{end}"
    session_id: str
    speaker: str                 # "Speaker_0" / "Speaker_1"
    start_time: float            # 秒（浮点）
    end_time: float
    duration: float
    content: str                 # 对应的文本内容
    audio_url: Optional[str]     # 提取后的片段音频 URL
```

---

## 13. 错误码与状态说明

### 13.1 HTTP 状态码

| 状态码 | 场景 |
|---|---|
| 200 | 请求成功（GET/PUT/DELETE） |
| 201 | 创建成功（POST 创建资源） |
| 400 | 请求参数有误（手机号格式错误、缺少必填字段） |
| 401 | 认证失败（JWT 无效、过期、缺少 Bearer） |
| 403 | 权限不足（操作他人资源、用户被禁用） |
| 404 | 资源不存在（session/profile/skill 不存在） |
| 500 | 服务内部错误（Gemini API 失败、数据库错误） |

### 13.2 业务状态码

所有成功响应统一返回 `{"code": 200, "message": "...", "data": {...}}`。

### 13.3 Session 状态流转

```
analyzing
    ↓（分析成功）
archived     ← 所有分析完成，strategy 可读取
    ↓（可手动）
completed    ← 与 archived 基本等价（旧版）

analyzing
    ↓（分析失败）
failed       ← error_message 字段含失败原因
```

### 13.4 连接池与超时配置

| 参数 | 默认值 | 说明 |
|---|---|---|
| DB pool_size | 20 | 常驻连接数 |
| DB max_overflow | 30 | 最大溢出连接 |
| DB pool_recycle | 3600 | 连接回收周期（秒） |
| Nginx proxy_read_timeout | 600s | 后端响应超时 |
| Nginx client_max_body_size | 200M | 上传文件大小上限 |
| Gemini Call #1 超时 | 360s (asyncio) | 语音转录最大等待 |
| Gemini 上传超时 | 90s (per file) | 单文件上传超时 |
| iOS 轮询策略 | 首次 8s, 之后每 3s, 最多 140 次 | ≈7 分钟 |

---

## 14. 北京服务器架构（只读节点）

### 14.1 服务器基本信息

| 项目 | 详情 |
|---|---|
| **公网 IP** | 123.57.29.111 |
| **内网 IP** | 172.24.54.214 |
| **主机名** | iZ2ze3ucqj0lkvtsv0pq6vZ |
| **OS** | Ubuntu 24.04.2 LTS (Linux 6.8.0-63-generic x86_64) |
| **云厂商** | 阿里云 ECS（北京区域） |
| **定位** | 只读 API 节点，为中国大陆用户加速读取 |
| **当前服务状态** | ⚠️ **应用未运行**（systemd 服务未安装/启用） |
| **Nginx** | 未安装 |

### 14.2 应用代码位置

```
/root/gemini-audio-service/
├── main.py              # 完整服务（3277行）—— 新加坡使用，北京存档
├── main_read.py         # 只读服务（759行）—— 北京目标入口
├── main_task_api.py     # 任务 API 模块（12KB）
├── .env                 # 环境变量配置
├── requirements.txt     # Python 依赖
├── api/
│   ├── auth.py          # 认证接口
│   ├── profiles.py      # 档案管理接口（13KB）
│   ├── skills.py        # 技能管理接口（16KB）
│   ├── galaxy.py        # 星图/内在宇宙接口（9KB）⭐ 北京独有
│   └── audio_segments.py # 音频片段提取接口（8KB）
├── database/
│   ├── connection.py    # SQLAlchemy 异步连接
│   ├── models.py        # ORM 模型
│   └── migrations/      # SQL 迁移脚本
├── auth/
│   ├── jwt_handler.py   # JWT 生成/验证
│   └── verification.py  # 验证码（mock 模式）
├── services/
│   ├── memory_service.py    # Mem0 + Qdrant 记忆服务
│   └── voiceprint_service.py # 声纹服务（当前为 mock）
├── utils/
│   ├── audio_storage.py     # 音频存储/OSS/ffmpeg
│   └── user_preferences.py  # 用户偏好工具
├── schemas/
│   └── strategy_schemas.py  # Pydantic 策略模型
├── skills/              # 与新加坡相同的12个技能模块
├── systemd/
│   └── *.service        # systemd 配置（未安装到 /etc/systemd/system/）
└── .venv/               # Python 3.9 虚拟环境
```

### 14.3 main_read.py — 只读服务详解

**设计理念**：北京节点仅提供读接口，所有写操作（音频上传、AI 分析、图片生成）均由新加坡节点处理。若请求需要生成策略，北京节点会返回重定向信息让 iOS 直接调用新加坡。

**启动入口**：
```python
# main_read.py
app = FastAPI(title="Gemini Audio Service (Read-Only)", version="0.8")
# 挂载路由：auth, tasks(只读), skills, profiles, audio_segments, galaxy, images
# 健康检查：GET /health → {"status": "ok", "mode": "read-only"}
```

#### 北京节点 API 端点列表

**认证**（与新加坡完全相同）：
- `POST /api/v1/auth/send-code` — 发送验证码
- `POST /api/v1/auth/login` — 登录（首次自动注册）
- `GET /api/v1/auth/me` — 获取当前用户信息

**任务（只读）**：
- `GET /api/v1/tasks/sessions` — 任务列表（分页，支持 date/status 过滤）
- `GET /api/v1/tasks/sessions/{session_id}` — 任务详情（含说话人名称解析）
- `GET /api/v1/tasks/sessions/{session_id}/status` — 任务进度状态
- `GET /api/v1/tasks/sessions/{session_id}/strategy` — 获取策略分析结果
  - 若策略尚未生成 → 返回 `{"need_generate": true, "write_base_url": "http://47.79.254.213"}`，iOS 自动转向新加坡
- `GET /api/v1/tasks/emotion-trend` — 情绪趋势数据

**技能**（与新加坡相同的完整 CRUD）：
- `GET /api/v1/skills` — 技能列表
- `GET /api/v1/skills/catalog` — 技能目录（含用户选中状态）
- `GET /api/v1/skills/{skill_id}` — 技能详情
- `GET/PUT /api/v1/skills/preferences` — 用户技能偏好

**档案**（与新加坡相同）：
- `GET/POST/PUT/DELETE /api/v1/profiles` — 档案 CRUD
- `POST /api/v1/profiles/upload-photo` — 头像上传到 OSS

**音频片段**：
- `GET /api/v1/tasks/sessions/{session_id}/audio-segments` — 获取片段列表
- `POST /api/v1/tasks/sessions/{session_id}/extract-segment` — 提取片段（调用 ffmpeg）

**图片代理**：
- `GET /api/v1/images/{session_id}/{image_index}` — 从 OSS 流式返回图片（需 JWT 认证）

**星图（Galaxy）** ⭐ 仅北京节点有此接口，新加坡暂未实装：
- `GET /api/v1/galaxy/overview` — 获取用户内在宇宙/星图数据

**健康检查**：
- `GET /health` — 返回 `{"status": "ok", "mode": "read-only"}`

### 14.4 星图（Galaxy）功能详解

**位置**：`api/galaxy.py`（9KB，约200行）

**设计理念**：根据用户历史 `skill_executions` 记录，将每次 AI 分析"映射"为星座点，形成用户专属的"内在宇宙星图"。

**星座映射规则**：

| 星座 ID | 星座名称 | 对应技能维度 | 所属领域 |
|---|---|---|---|
| `command` | 统御座 | role_position（managing_up/managing_down） | 职场 |
| `game` | 博弈座 | scenario（negotiation/conflict_resolution） | 职场 |
| `wisdom` | 智慧座 | capability（logical_thinking/eq/influence） | 职场 |
| `bond` | 羁绊座 | family_relationship / education_communication | 家庭 |
| `dawn` | 启明星 | career_stage（rookie/executive） | 职场 |
| `heal` | 自愈座 | emotion_recognition / depression_prevention | 个人 |

**接口响应结构**：
```json
{
  "code": 200,
  "data": {
    "user_id": "<uuid>",
    "sectors": [
      {
        "id": "workplace",
        "name": "职场",
        "constellations": [
          {
            "id": "command",
            "name": "统御座",
            "level": 3,
            "xp": 1250,
            "xp_to_next": 2000,
            "sessions_count": 8,
            "last_activated": "2026-02-20T14:00:00",
            "stars": [
              {"skill_id": "workplace_role", "sub_skill": "managing_up", "activated_at": "..."}
            ]
          }
        ]
      },
      {"id": "family",   "name": "家庭",   "constellations": [...]},
      {"id": "personal", "name": "个人成长", "constellations": [...]}
    ],
    "total_sessions": 42,
    "most_active_constellation": "command",
    "generated_at": "2026-02-27T09:00:00"
  }
}
```

**等级计算逻辑**：
```
每次技能执行（skill_executions 记录）→ 对应星座 +100 XP
Level 1: 0-499 XP
Level 2: 500-1499 XP
Level 3: 1500-3499 XP
Level 4: 3500-7499 XP
Level 5: 7500+ XP（最高级）
```

### 14.5 北京节点数据库配置

```
# 北京 .env（关键字段，凭据已脱敏）
DATABASE_URL=postgresql+asyncpg://[user]:[pass]@pgm-2ze5w19pz5t064k04o.pg.rds.aliyuncs.com:5432/gemini_audio_db
DATABASE_SSL=false          # ← 与新加坡不同，北京 RDS 连接未启用 SSL

PROXY_URL=http://47.79.254.213/secret-channel  # 通过新加坡代理访问 Gemini（若需要）
USE_PROXY=true
PROXY_FORCE_LOCALHOST=false  # 北京与新加坡不同机

OSS_ENDPOINT=oss-cn-beijing.aliyuncs.com  # ← 北京 OSS 节点
OSS_BUCKET_NAME=geminipicture2

VERIFICATION_CODE_MOCK=true  # 开发模式，验证码固定 123456
```

**与新加坡 .env 的关键差异**：

| 配置项 | 北京 | 新加坡 |
|---|---|---|
| DATABASE_SSL | false | true |
| PROXY_FORCE_LOCALHOST | false | true |
| OSS_ENDPOINT | oss-cn-beijing | oss-cn-hangzhou |
| USE_OSS_FOR_ORIGINAL_AUDIO | false | false |
| GEMINI 调用 | 无（只读） | 有（全量） |

### 14.6 北京节点 systemd 服务配置

```ini
# /root/gemini-audio-service/systemd/gemini-audio-read.service
# ⚠️ 注意：此文件路径有误，未安装，服务未启用

[Unit]
Description=Gemini Audio Service Read-Only (uvicorn port 8000)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/gemini-audio-service
Environment=PATH=/root/gemini-audio-service/.venv/bin
ExecStart=/root/gemini-audio-service/.venv/bin/uvicorn main_read:app \
    --host 0.0.0.0 --port 8000 --workers 4
Restart=on-failure
RestartSec=5
StandardOutput=append:/root/gemini-audio-service.log
StandardError=append:/root/gemini-audio-service.log

[Install]
WantedBy=multi-user.target
```

> **已知问题**：systemd 服务文件中路径/用户名有误（写的是 `/home/admin/` 而非 `/root/`），且从未安装到 `/etc/systemd/system/`，故北京节点目前处于**停止状态**，需手动修复并启动。

**启动北京服务的正确命令**：
```bash
# 1. 进入项目目录
cd /root/gemini-audio-service

# 2. 激活虚拟环境
source .venv/bin/activate

# 3. 手动启动（调试用）
uvicorn main_read:app --host 0.0.0.0 --port 8000 --workers 4

# 4. 或修复并安装 systemd 服务
cp systemd/gemini-audio-read.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable gemini-audio-read
systemctl start gemini-audio-read
```

### 14.7 两节点对比总览

| 维度 | 新加坡节点（主） | 北京节点（读） |
|---|---|---|
| **IP** | 47.79.254.213 | 123.57.29.111 |
| **入口文件** | main.py（3277行） | main_read.py（759行） |
| **Nginx** | 已安装，port 80 → :8000，`/secret-channel` 代理 | 未安装 |
| **systemd** | 已安装并运行 | 未安装，服务停止 |
| **Python 虚拟环境** | venv（Python 3.12+） | .venv（Python 3.9） |
| **音频上传** | ✅ POST /api/v1/audio/upload | ❌ 无此端点 |
| **AI 分析（Gemini）** | ✅ Call #1 转录 + Call #2 策略 + 图片生成 | ❌ 无 Gemini 调用 |
| **策略查询** | ✅ 直接读取 | ✅（若无结果则返回重定向到新加坡） |
| **星图 Galaxy** | ❌ 未实装 | ✅ GET /api/v1/galaxy/overview |
| **声纹服务** | Mock（计划接入阿里云 Speaker Verification） | 同上 |
| **记忆服务** | Mem0 + Qdrant（可选）| 同上 |
| **OSS Region** | oss-cn-hangzhou（杭州节点） | oss-cn-beijing（北京节点） |
| **数据库** | 共享同一 RDS 实例 | 共享同一 RDS 实例 |
| **数据库 SSL** | true | false |

### 14.8 iOS 双节点路由策略

```swift
// AppConfig.swift
var readBaseURL:  String { "http://123.57.29.111:8000/api/v1" }  // 北京（读）
var writeBaseURL: String { "http://47.79.254.213/api/v1" }        // 新加坡（写）

// NetworkManager.swift 路由规则：
// 写节点（新加坡）：
//   POST /audio/upload
//   POST /auth/send-code, /auth/login
//   POST/PUT/DELETE /profiles
//   PUT /skills/preferences
//   PUT /users/me/preferences
//   POST /sessions/{id}/extract-segment
//
// 读节点（北京）：
//   GET /tasks/sessions（列表/详情/状态/策略）
//   GET /skills, /skills/catalog, /skills/{id}
//   GET /profiles
//   GET /images/{session_id}/{index}
//   GET /auth/me
//   GET /galaxy/overview
//   GET /tasks/emotion-trend
```

**策略生成的特殊路由**：
```
iOS 请求 GET /tasks/sessions/{id}/strategy
    ↓ 北京节点返回
    if 策略已存在:
        → 直接返回 skill_cards 数据
    else:
        → 返回 {"need_generate": true, "write_base_url": "http://47.79.254.213"}
            ↓
        iOS 自动向新加坡节点 POST /sessions/{id}/strategies 触发生成
```

---

## 附录：技能库清单

### A. 父技能（后端匹配层）

| 父技能 ID | 名称（DB值） | 分类 | 优先级 | 场景维度 | 后端匹配规则 | 子技能数 |
|---|---|---|---|---|---|---|
| `workplace_role` | 角色方位分析 | workplace | 100 | role_position | LLM 识别 role_position 维度 | 4 |
| `workplace_scenario` | 场景情境分析 | workplace | 95 | scenario | LLM 识别 scenario 维度 | 5 |
| `workplace_psychology` | 心理风格分析 | workplace | 85 | psychology | LLM 识别 psychology 维度 | 4 |
| `workplace_career` | 职业阶段分析 | workplace | 80 | career_stage | LLM 识别 career_stage 维度 | 3 |
| `workplace_capability` | 能力维度分析 | workplace | 75 | capability | LLM 识别 capability 维度 | 3 |
| `brainstorm` | 头脑风暴协作 | workplace | 70 | - | LLM 识别创意讨论场景 | 0（自身入目录）|
| `workplace_jungle` | 职场丛林法则 | workplace | 100 | - | ❌ **已停用**（`enabled=false`），不出现在目录中 | - |
| `family_relationship` | 亲密关系沟通 | family | 90 | - | LLM 识别 family 场景 | 0（自身入目录）|
| `education_communication` | 教育沟通引导 | family | 80 | - | LLM 识别 family 场景 | 0（自身入目录）|
| `emotion_recognition` | 情绪识别 | personal | 50 | - | **始终追加**（所有对话） | 0（自身入目录）|
| `depression_prevention` | 防抑郁监控 | personal | 45 | - | 危机词/负面词条件触发 | 0（自身入目录）|

> 注：优先级数值来自数据库实际值；`brainstorm` 在数据库中分类为 `workplace`；父技能 ID 仅用于 LLM 路由匹配，**不直接展示给用户**。

---

### B. 用户可见技能目录（iOS 技能库）

iOS App 「技能库」页面展示的是**子技能**（共 24 条，含4条家庭/个人分类中的整体技能）。用户可选择、查看详情的都是下列条目。

**职场（20个）**

| 用户看到的技能名称 | 子技能 ID | 所属父技能 | 封面颜色 |
|---|---|---|---|
| 向上管理 | `managing_up` | workplace_role | #FF6B6B |
| 向下管理 | `managing_down` | workplace_role | #4ECDC4 |
| 横向协作 | `peer_collaboration` | workplace_role | #45B7D1 |
| 对外沟通 | `external_communication` | workplace_role | #96CEB4 |
| 冲突化解 | `conflict_resolution` | workplace_scenario | #E74C3C |
| 谈判博弈 | `negotiation` | workplace_scenario | #F39C12 |
| 汇报展示 | `presentation` | workplace_scenario | #3498DB |
| 闲聊社交 | `small_talk` | workplace_scenario | #2ECC71 |
| 危机公关 | `crisis_management` | workplace_scenario | #9B59B6 |
| 防御技能 | `defensive` | workplace_psychology | #7F8C8D |
| 进攻技型 | `offensive` | workplace_psychology | #E67E22 |
| 建设技能 | `constructive` | workplace_psychology | #27AE60 |
| 治愈技能 | `healing` | workplace_psychology | #FF9FF3 |
| 新人小白技能 | `rookie` | workplace_career | #74B9FF |
| 骨干/中层技能 | `core_manager` | workplace_career | #A29BFE |
| 高管/领袖技能 | `executive` | workplace_career | #6C5CE7 |
| 逻辑思维技能 | `logical_thinking` | workplace_capability | #00B894 |
| 情商提升 | `eq` | workplace_capability | #FDCB6E |
| 影响力提升 | `influence` | workplace_capability | #E17055 |
| 头脑风暴协作 | `brainstorm` | brainstorm | #FD79A8 |

**家庭（2个）**

| 用户看到的技能名称 | 子技能 ID | 所属父技能 | 封面颜色 |
|---|---|---|---|
| 亲密关系沟通 | `family_relationship` | family_relationship | #E84393 |
| 教育沟通引导 | `education_communication` | education_communication | #00CEC9 |

**个人成长（2个）**

| 用户看到的技能名称 | 子技能 ID | 所属父技能 | 封面颜色 |
|---|---|---|---|
| 情绪识别 | `emotion_recognition` | emotion_recognition | #FFEAA7 |
| 防抑郁监控 | `depression_prevention` | depression_prevention | #81ECEC |

---

*本文档由新加坡（47.79.254.213）和北京（123.57.29.111）两台服务器代码分析整理生成，最后更新：2026-02-27。如有变动请同步更新。*
