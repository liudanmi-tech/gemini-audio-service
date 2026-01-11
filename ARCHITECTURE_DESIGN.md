# 职场生存指南 - 技术架构设计文档

## 1. 系统概述

### 1.1 产品定位
- **产品名称**: 职场生存指南（Work Survival Guide）
- **核心定位**: 职场电子宠物 + 智能军师
- **核心价值**: 情绪价值优先，游戏化职场体验
- **目标用户**: 00后/95后职场人

### 1.2 技术架构总览
```
┌─────────────────────────────────────────────────────────────┐
│                     移动端 (iOS Native - Swift)              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  任务(副本)  │  │  状态(牛马)   │  │  档案(图鉴)   │    │
│  │  ✅ 已实现   │  │  ⏳ 待开发    │  │  ⏳ 待开发    │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ HTTPS
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    API Gateway (Nginx)                       │
│  - 反向代理 Gemini API (已配置)                               │
│  - API 路由 (待配置)                                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│             后端服务层 (FastAPI) - ✅ 已实现                  │
│  ┌────────────────────────────────────────────────────┐   │
│  │  任务服务 (Task Service)                             │   │
│  │  - POST /api/v1/audio/upload (上传音频)            │   │
│  │  - GET /api/v1/tasks/sessions (任务列表)           │   │
│  │  - GET /api/v1/tasks/sessions/{id} (任务详情)      │   │
│  │  - GET /api/v1/tasks/sessions/{id}/status (状态)   │   │
│  └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Gemini API (已配置)                       │
│  - 音频上传和分析一体化 ✅                                     │
│  - 对话提取、情绪分析、风险识别 ✅                              │
│  - 模型: gemini-3-flash-preview ✅                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    数据存储层                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │ 内存存储     │  │  Redis       │  │ 对象存储 OSS │    │
│  │ (临时) ✅    │  │ (缓存/队列)  │  │ (音频文件)   │    │
│  │              │  │ ⏳ 待实现    │  │ ⏳ 待实现    │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│  ⚠️ 当前使用内存存储，后续需要迁移到 PostgreSQL              │
└─────────────────────────────────────────────────────────────┘
```

## 2. 技术栈选型

### 2.1 后端技术栈
- **Web 框架**: FastAPI 0.104.1+
- **Python 版本**: 3.14
- **异步框架**: asyncio + aiohttp
- **ORM**: SQLAlchemy 2.0 (异步)
- **数据库**: PostgreSQL 15+
- **缓存/队列**: Redis 7+
- **对象存储**: 阿里云 OSS
- **任务队列**: Celery + Redis (异步任务处理)

### 2.2 AI 服务集成
- **音频分析**: Google Gemini 3 Flash Preview (已配置)
  - **一体化处理**: 音频上传后直接由 Gemini 进行转写、分析和理解
  - **功能**: 对话提取、说话人识别、情绪分析、风险识别、策略建议
  - **优势**: 无需额外的 ASR 服务，简化架构，降低延迟

### 2.3 前端技术栈
- **移动端框架**: iOS Native (Swift 5.9+)
- **UI 框架**: SwiftUI
- **架构模式**: MVVM (Model-View-ViewModel)
- **网络库**: URLSession + Combine / Alamofire
- **音频录制**: AVAudioRecorder (iOS 原生框架)
- **状态管理**: Combine / @State / @ObservableObject
- **数据持久化**: Core Data / UserDefaults
- **WebSocket**: URLSessionWebSocketTask (实时状态更新)

### 2.4 基础设施
- **反向代理**: Nginx (已配置，用于 Gemini API)
- **容器化**: Docker + Docker Compose
- **CI/CD**: GitHub Actions
- **监控**: Prometheus + Grafana
- **日志**: ELK Stack (Elasticsearch + Logstash + Kibana)

## 3. 系统模块设计

### 3.1 音频服务模块 (Audio Service)

#### 3.1.1 功能职责
- 接收 iOS 端上传的音频文件
- 音频格式验证和预处理（可选）
- 直接上传到 Gemini API 进行分析（一体化处理）
- 将分析结果保存到数据库
- 管理录音会话的生命周期

#### 3.1.2 API 设计
```python
# POST /api/v1/audio/upload
# 上传音频文件并直接分析（一体化处理）
Request:
  - file: multipart/form-data (mp3/wav/m4a)
  - session_id: string (可选，继续之前的会话)
  - metadata: json (设备信息、位置等)
  - persona_mode: string (可选，军师模式)

Response:
  {
    "session_id": "uuid",
    "audio_id": "uuid",
    "status": "analyzing",  # analyzing|completed|failed
    "estimated_duration": 300  # 秒
  }

# GET /api/v1/audio/{audio_id}/status
# 查询分析状态
Response:
  {
    "audio_id": "uuid",
    "analysis_status": "processing|completed|failed",
    "progress": 0.75,  # 0-1
    "analysis_id": "uuid"  # 分析结果ID（完成时返回）
  }
```

#### 3.1.3 技术实现要点
- **一体化处理流程**:
  1. 接收 iOS 端上传的音频文件
  2. 直接上传到 Gemini API（使用 `genai.upload_file`）
  3. 等待文件状态变为 ACTIVE
  4. 调用 Gemini 模型进行分析（转写 + 理解 + 分析）
  5. 解析返回结果并保存到数据库
- **异步处理**: 分析任务放入 Celery 队列，避免阻塞 API 响应
- **文件存储**: 可选上传到 OSS 进行持久化存储（用于后续回放）

### 3.2 分析服务模块 (Analysis Service)

#### 3.2.1 功能职责
- 调用 Gemini API 进行深度分析
- 对话分段和主题识别
- 情绪检测和风险识别
- 生成策略建议（基于军师模式）
- 计算情绪分数和统计数据

#### 3.2.2 API 设计
```python
# POST /api/v1/analysis/analyze
# 分析音频会话（音频上传时自动调用，也可单独调用）
Request:
  {
    "session_id": "uuid",
    "audio_id": "uuid",  # 音频文件ID（Gemini 文件 ID）
    "persona_mode": "veteran|newbie|strong|lying_flat",  # 军师模式
    "analysis_type": "full|quick"  # 完整分析或快速分析
  }

Response:
  {
    "analysis_id": "uuid",
    "session_id": "uuid",
    "emotion_score": 60,  # 0-100
    "speaker_count": 3,
    "total_turns": 120,
    "sigh_count": 8,
    "segments": [
      {
        "segment_id": "uuid",
        "title": "Q1预算讨论",
        "start_time": 0.0,
        "end_time": 320.0,
        "summary": "一段话总结",
        "emotion_tags": ["#PUA预警", "#急躁", "#画饼"],
        "strategy": {
          "type": "warning|suggestion|action",
          "content": "老板正在施压，建议回复：...",
          "tone": "calm|firm|diplomatic"
        },
        "risks": ["风险点1", "风险点2"]
      }
    ],
    "dialogues": [
      {
        "speaker": "speaker_1",
        "content": "具体内容",
        "tone": "平静|愤怒|轻松",
        "timestamp": 10.5,
        "cpm": 180  # 字符每分钟（语速）
      }
    ]
  }

# GET /api/v1/analysis/{analysis_id}/strategy
# 获取详细策略建议
Request:
  - persona_mode: string
  - segment_id: string (可选)

Response:
  {
    "strategies": [
      {
        "segment_id": "uuid",
        "context": "当前对话上下文",
        "suggestions": [
          {
            "type": "reply|action|avoid",
            "content": "建议话术",
            "reason": "原因说明"
          }
        ]
      }
    ]
  }
```

#### 3.2.3 技术实现要点
- **对话分段算法**:
  ```python
  # 分段策略
  1. 时间间隔 > 5分钟 → 新段落
  2. 主题切换检测（基于 Gemini 语义分析）
  3. 说话人切换 + 长时间停顿
  ```
- **情绪检测**:
  - 文本情绪: 基于 Gemini 分析对话内容
  - 语速检测: CPM (Characters Per Minute) > 常规值 1.5倍 → 急躁
  - 叹气检测: ASR 返回的 `(sigh)` 标记 + VAD 静音段分析
- **军师模式 Prompt 模板**:
  ```python
  PERSONA_PROMPTS = {
    "veteran": "你是一个职场老油条，擅长用拖字诀和糊弄文学...",
    "newbie": "你是一个职场小白兔，需要学会委婉拒绝...",
    "strong": "你是钮祜禄模式，建议如何回怼，争取资源...",
    "lying_flat": "你选择躺平，只总结重点，忽略PUA话术..."
  }
  ```

### 3.3 档案服务模块 (Profile Service)

#### 3.3.1 功能职责
- 管理说话人档案（Speaker Profile）
- 声纹识别和映射
- 人物性格分析
- 历史对话记录查询
- 人物关系图谱构建

#### 3.3.2 API 设计
```python
# GET /api/v1/profile/speakers
# 获取所有说话人列表
Response:
  {
    "registered": [
      {
        "speaker_id": "uuid",
        "name": "王总",
        "avatar": "avatar_id",
        "avatar_type": "周扒皮|笑面虎|猪队友|正常人",
        "personality_tags": ["#D型人格", "#结果导向", "#喜怒无常"],
        "appearance_count": 15,
        "last_seen": "2026-01-03T10:30:00Z"
      }
    ],
    "unregistered": [
      {
        "speaker_id": "speaker_1",
        "appearance_count": 3,
        "last_seen": "2026-01-03T09:00:00Z",
        "sample_audio_url": "oss://.../sample_5s.wav"
      }
    ]
  }

# POST /api/v1/profile/speakers/register
# 注册说话人
Request:
  {
    "speaker_id": "speaker_1",
    "name": "王总",
    "avatar_type": "周扒皮",
    "sample_audio_segments": ["segment_id_1", "segment_id_2"]  # 用于声纹注册
  }

Response:
  {
    "speaker_id": "uuid",
    "voiceprint_id": "aliyun_voiceprint_id",
    "status": "registered"
  }

# GET /api/v1/profile/speakers/{speaker_id}
# 获取说话人详情
Response:
  {
    "speaker_id": "uuid",
    "name": "王总",
    "avatar": {...},
    "personality_analysis": {
      "tags": ["#D型人格", "#结果导向"],
      "summary": "此人喜欢听数据，不喜欢听过程；周一心情通常不好。",
      "communication_style": "direct|indirect|emotional|rational"
    },
    "interaction_history": {
      "total_sessions": 15,
      "total_duration": 7200,  # 秒
      "emotion_trend": [
        {"date": "2026-01-01", "avg_emotion": 65},
        {"date": "2026-01-02", "avg_emotion": 45}
      ]
    },
    "audio_samples": [
      {
        "segment_id": "uuid",
        "url": "oss://...",
        "duration": 5.0,
        "text": "采样文本"
      }
    ],
    "strategy_notes": "攻略笔记内容..."
  }

# POST /api/v1/profile/speakers/{speaker_id}/voiceprint/verify
# 验证声纹（用于自动识别）
Request:
  {
    "audio_segment_id": "uuid"
  }

Response:
  {
    "matched": true,
    "confidence": 0.92,
    "speaker_id": "uuid"
  }
```

#### 3.3.3 技术实现要点
- **声纹识别流程**:
  1. ASR 返回 `speaker_cluster_id`
  2. 后端调用阿里云 Speaker Verification API 注册声纹
  3. 建立 `speaker_cluster_id` → `registered_speaker_id` 映射
  4. 后续自动识别时，先查映射表，再调用声纹验证 API
- **性格分析**:
  - 基于历史对话，使用 Gemini 分析
  - Prompt: "基于以下对话历史，分析此人的性格特点、沟通风格、行为模式..."
- **人物关系图谱**:
  - 使用 Neo4j 或 PostgreSQL + JSONB 存储关系数据
  - 分析共同出现的频率、对话模式等

### 3.4 任务服务模块 (Task Service)

#### 3.4.1 功能职责
- 管理录音会话（Session）
- 任务列表和详情
- 任务状态流转
- 任务归档和删除（焚毁功能）

#### 3.4.2 API 设计
```python
# GET /api/v1/tasks/sessions
# 获取任务列表（按天聚合）
Request:
  - date: string (YYYY-MM-DD, 可选，默认今天)
  - status: string (recording|analyzing|archived|burned, 可选)
  - page: int
  - page_size: int

Response:
  {
    "sessions": [
      {
        "session_id": "uuid",
        "title": "Q1预算撕逼会",
        "start_time": "2026-01-03T10:30:00Z",
        "end_time": "2026-01-03T11:15:00Z",
        "duration": 2700,  # 秒
        "tags": ["#PUA预警", "#急躁", "#画饼"],
        "status": "archived",
        "emotion_score": 60,
        "speaker_count": 3,
        "thumbnail_url": "oss://..."  # 会话缩略图（可选）
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 100
    }
  }

# GET /api/v1/tasks/sessions/{session_id}
# 获取任务详情
Response:
  {
    "session_id": "uuid",
    "title": "Q1预算撕逼会",
    "metadata": {...},
    "emotion_stats": {
      "score": 60,
      "total_turns": 120,
      "sigh_count": 8,
      "sigh_timestamps": [45.2, 120.5, ...]
    },
    "segments": [...],  # 同分析服务的 segments
    "dialogues": [...],  # 同分析服务的 dialogues
    "analysis_id": "uuid"
  }

# POST /api/v1/tasks/sessions/{session_id}/burn
# 焚毁任务（软删除）
Response:
  {
    "session_id": "uuid",
    "status": "burned",
    "burned_at": "2026-01-03T12:00:00Z"
  }

# GET /api/v1/tasks/sessions/{session_id}/export
# 导出任务（PDF/文本）
Request:
  - format: string (pdf|txt|json)

Response:
  - File download
```

### 3.5 状态服务模块 (Status Service)

#### 3.5.1 功能职责
- 管理用户状态（老黄牛 Avatar）
- 情绪压力桶计算
- 生成"嘴替"吐槽内容
- 记录"还回去"操作

#### 3.5.2 API 设计
```python
# GET /api/v1/status/avatar
# 获取当前 Avatar 状态
Response:
  {
    "avatar_state": "good|normal|bad",
    "avatar_image_url": "cdn://...",
    "pressure_level": 0.75,  # 0-1
    "pressure_bucket": {
      "current": 75,
      "max": 100,
      "can_vent": true  # 是否满了可以"还回去"
    },
    "stats": {
      "today_sessions": 5,
      "today_emotion_avg": 55,
      "today_sigh_count": 12,
      "burned_tasks_today": 2
    }
  }

# POST /api/v1/status/vent
# 触发"还回去"宣泄
Request:
  {
    "vent_type": "mouth_replacement|physical_venting|both"
  }

Response:
  {
    "vent_id": "uuid",
    "mouth_replacement": {
      "content": "这破班一秒都不想上了！",
      "bullet_comments": [
        "画饼充饥，老板你吃了吗？",
        "这破班一秒都不想上了！"
      ]
    },
    "physical_venting": {
      "animation_sequence": ["transform", "punch_1", "punch_2", "reset"],
      "haptic_pattern": [100, 200, 300, 400]  # 震动模式（毫秒）
    },
    "rewards": [
      {"type": "merit", "value": 1, "name": "功德+1"},
      {"type": "health", "value": 1, "name": "乳腺通畅+1"}
    ],
    "pressure_after": 0.0  # 清空
  }

# GET /api/v1/status/history
# 获取状态历史（用于趋势分析）
Request:
  - days: int (默认7天)

Response:
  {
    "history": [
      {
        "date": "2026-01-01",
        "emotion_score": 65,
        "pressure_level": 0.5,
        "sessions_count": 3,
        "vent_count": 1
      }
    ]
  }
```

#### 3.5.3 技术实现要点
- **压力桶计算逻辑**:
  ```python
  pressure_increase = (
    sigh_count * 0.1 +
    negative_emotion_segments * 0.15 +
    pua_detected * 0.2 +
    high_stress_keywords * 0.1
  )
  ```
- **嘴替生成**:
  - 基于当日所有会话的负面内容
  - 使用 Gemini 生成犀利吐槽（Prompt: "基于以下职场对话，生成一段解压的吐槽，要求犀利、幽默、解压..."）
- **Avatar 状态切换**:
  ```python
  if emotion_score > 70 and burned_tasks_today > 0:
    state = "good"
  elif emotion_score < 40 or sigh_count > threshold:
    state = "bad"
  else:
    state = "normal"
  ```

## 4. 数据模型设计

### 4.1 核心数据表

#### 4.1.1 sessions (录音会话表)
```sql
CREATE TABLE sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(255),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration INTEGER,  -- 秒
    status VARCHAR(20) NOT NULL,  -- recording|analyzing|archived|burned
    audio_id UUID REFERENCES audio_files(audio_id),
    transcript_id UUID REFERENCES transcripts(transcript_id),
    analysis_id UUID REFERENCES analyses(analysis_id),
    emotion_score INTEGER,  -- 0-100
    speaker_count INTEGER,
    tags TEXT[],  -- 标签数组
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    burned_at TIMESTAMP
);

CREATE INDEX idx_sessions_user_date ON sessions(user_id, DATE(created_at));
CREATE INDEX idx_sessions_status ON sessions(status);
```

#### 4.1.2 audio_files (音频文件表)
```sql
CREATE TABLE audio_files (
    audio_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES sessions(session_id),
    file_name VARCHAR(255),
    file_size BIGINT,
    file_format VARCHAR(10),
    oss_url VARCHAR(500),
    transcribe_status VARCHAR(20),  -- pending|processing|completed|failed
    transcribe_progress FLOAT,  -- 0-1
    aliyun_task_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### 4.1.3 transcripts (转写结果表)
```sql
CREATE TABLE transcripts (
    transcript_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audio_id UUID REFERENCES audio_files(audio_id),
    full_text TEXT,
    segment_count INTEGER,
    speakers TEXT[],  -- speaker_id 数组
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE transcript_segments (
    segment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transcript_id UUID REFERENCES transcripts(transcript_id),
    start_time FLOAT,
    end_time FLOAT,
    text TEXT,
    speaker_id VARCHAR(50),
    confidence FLOAT,
    cpm INTEGER,  -- 字符每分钟（语速）
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_segments_transcript ON transcript_segments(transcript_id);
CREATE INDEX idx_segments_speaker ON transcript_segments(speaker_id);
```

#### 4.1.4 analyses (分析结果表)
```sql
CREATE TABLE analyses (
    analysis_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID REFERENCES sessions(session_id),
    transcript_id UUID REFERENCES transcripts(transcript_id),
    persona_mode VARCHAR(20),  -- veteran|newbie|strong|lying_flat
    emotion_score INTEGER,
    total_turns INTEGER,
    sigh_count INTEGER,
    sigh_timestamps FLOAT[],
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE analysis_segments (
    segment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID REFERENCES analyses(analysis_id),
    title VARCHAR(255),
    start_time FLOAT,
    end_time FLOAT,
    summary TEXT,
    emotion_tags TEXT[],
    strategy_content TEXT,
    strategy_type VARCHAR(20),
    risks TEXT[],
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE analysis_dialogues (
    dialogue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID REFERENCES analyses(analysis_id),
    segment_id UUID REFERENCES analysis_segments(segment_id),
    speaker_id VARCHAR(50),
    speaker_name VARCHAR(100),  -- 如果已注册
    content TEXT,
    tone VARCHAR(50),
    timestamp FLOAT,
    cpm INTEGER,
    created_at TIMESTAMP DEFAULT NOW()
);
```

#### 4.1.5 speakers (说话人档案表)
```sql
CREATE TABLE speakers (
    speaker_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name VARCHAR(100),
    avatar_type VARCHAR(50),  -- 周扒皮|笑面虎|猪队友|正常人
    avatar_image_url VARCHAR(500),
    aliyun_voiceprint_id VARCHAR(100),
    personality_tags TEXT[],
    personality_summary TEXT,
    communication_style VARCHAR(50),
    strategy_notes TEXT,
    appearance_count INTEGER DEFAULT 0,
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE speaker_cluster_mapping (
    mapping_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    cluster_id VARCHAR(50),  -- ASR 返回的 speaker_cluster_id
    speaker_id UUID REFERENCES speakers(speaker_id),
    confidence FLOAT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, cluster_id)
);

CREATE INDEX idx_speakers_user ON speakers(user_id);
CREATE INDEX idx_mapping_cluster ON speaker_cluster_mapping(cluster_id);
```

#### 4.1.6 user_status (用户状态表)
```sql
CREATE TABLE user_status (
    user_id UUID PRIMARY KEY,
    avatar_state VARCHAR(20) DEFAULT 'normal',  -- good|normal|bad
    pressure_level FLOAT DEFAULT 0.0,  -- 0-1
    total_merit INTEGER DEFAULT 0,  -- 功德值
    total_health INTEGER DEFAULT 0,  -- 健康值
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE vent_history (
    vent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    vent_type VARCHAR(50),
    pressure_before FLOAT,
    pressure_after FLOAT,
    rewards JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### 4.2 Redis 数据结构

```python
# 会话状态缓存
session:{session_id} = {
    "status": "recording|analyzing|archived",
    "emotion_score": 60,
    "updated_at": "2026-01-03T10:30:00Z"
}

# 用户压力桶
pressure:{user_id} = {
    "current": 75,
    "max": 100,
    "last_update": "2026-01-03T10:30:00Z"
}

# 实时转写进度
transcribe:{audio_id} = {
    "progress": 0.75,
    "status": "processing"
}
```

## 5. 第三方服务集成

### 5.1 阿里云智能语音服务

#### 5.1.1 File Transcribe API
```python
# 配置
ALIYUN_ACCESS_KEY_ID = os.getenv("ALIYUN_ACCESS_KEY_ID")
ALIYUN_ACCESS_KEY_SECRET = os.getenv("ALIYUN_ACCESS_KEY_SECRET")
ALIYUN_REGION = "cn-shanghai"

# 调用流程
1. 上传音频到 OSS
2. 调用 SubmitTask API 提交转写任务
3. 轮询 GetTaskResult API 获取结果
4. 解析返回的 JSON，提取 segments 和 speakers
```

#### 5.1.2 Speaker Verification API
```python
# 声纹注册
1. 提取说话人的音频片段（至少 3-5 秒）
2. 调用 AddVoice API 注册声纹
3. 保存 voiceprint_id 到数据库

# 声纹识别
1. 提取待识别音频片段
2. 调用 VerifyVoice API
3. 返回匹配的 speaker_id 和 confidence
```

### 5.2 Google Gemini API (已配置)
- **基础配置**: 已通过反向代理配置完成
- **使用场景**:
  - 对话分段和主题识别
  - 情绪分析和风险识别
  - 策略建议生成
  - 性格分析
  - 嘴替内容生成

### 5.3 阿里云 OSS
- **用途**: 音频文件持久化存储
- **配置**:
  - Bucket: `work-survival-audio`
  - 区域: 华东1（杭州）
  - 访问控制: 私有读写，通过 STS 临时授权访问

## 6. 前端交互技术方案

### 6.1 3D 翻转效果实现

#### React Native 方案
```javascript
import Animated, { useSharedValue, useAnimatedStyle, withTiming } from 'react-native-reanimated';

const rotateY = useSharedValue(0);

const flip = () => {
  rotateY.value = rotateY.value === 0 ? 180 : 0;
};

const animatedStyle = useAnimatedStyle(() => {
  return {
    transform: [{ rotateY: `${rotateY.value}deg` }],
  };
});

// 使用 backfaceVisibility 实现双面效果
<Animated.View style={[styles.container, animatedStyle]}>
  <View style={styles.front}>
    {/* 工作模式内容 */}
  </View>
  <View style={styles.back}>
    {/* 生活模式内容 */}
  </View>
</Animated.View>
```

#### Flutter 方案
```dart
import 'package:flutter/material.dart';

class FlipWidget extends StatefulWidget {
  @override
  _FlipWidgetState createState() => _FlipWidgetState();
}

class _FlipWidgetState extends State<FlipWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);
  }

  void flip() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(_animation.value * 3.14159),
          child: _animation.value < 0.5
              ? FrontWidget()  // 工作模式
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(3.14159),
                  child: BackWidget(),  // 生活模式
                ),
        );
      },
    );
  }
}
```

### 6.2 录音功能实现

#### React Native
```javascript
import AudioRecorderPlayer from 'react-native-audio-recorder-player';

const audioRecorderPlayer = new AudioRecorderPlayer();

// 开始录音
const startRecord = async () => {
  const result = await audioRecorderPlayer.startRecorder();
  audioRecorderPlayer.addRecordBackListener((e) => {
    // 实时更新录音时长
    setRecordTime(audioRecorderPlayer.mmssss(e.currentPosition));
  });
};

// 停止录音并上传
const stopRecord = async () => {
  const result = await audioRecorderPlayer.stopRecorder();
  // 上传 result 到后端
};
```

#### Flutter
```dart
import 'package:flutter_sound/flutter_sound.dart';

final recorder = FlutterSoundRecorder();

// 开始录音
await recorder.startRecorder(
  toFile: 'audio.wav',
  codec: Codec.pcm16WAV,
);

// 停止录音
final path = await recorder.stopRecorder();
// 上传 path 到后端
```

### 6.3 实时状态更新 (WebSocket)

```python
# 后端 WebSocket 端点
@app.websocket("/ws/status/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await websocket.accept()
    try:
        while True:
            # 发送实时状态更新
            status = await get_user_status(user_id)
            await websocket.send_json(status)
            await asyncio.sleep(1)
    except WebSocketDisconnect:
        pass
```

```javascript
// 前端 WebSocket 连接
const ws = new WebSocket('ws://api.example.com/ws/status/user_id');

ws.onmessage = (event) => {
  const status = JSON.parse(event.data);
  updateAvatarState(status.avatar_state);
  updatePressureBucket(status.pressure_bucket);
};
```

### 6.4 动画效果

#### 压力桶动画
- 使用 `react-native-reanimated` 或 Flutter `AnimationController`
- 根据 `pressure_level` 动态调整水位高度
- 添加液体流动效果（使用 `react-native-svg` 或 Flutter `CustomPainter`）

#### 焚毁动效
- 使用 Lottie 动画（火焰效果）
- 或使用 Canvas 绘制粒子效果
- 配合震动反馈（Haptic Feedback）

#### 爆锤动效
- 序列帧动画（transform → punch_1 → punch_2 → reset）
- 配合震动模式（不同强度的震动序列）

## 7. 安全设计

### 7.1 认证授权
- **JWT Token**: 用户登录后获取 JWT，后续请求携带 Token
- **Token 刷新**: Refresh Token 机制
- **权限控制**: RBAC（Role-Based Access Control）

### 7.2 数据安全
- **音频文件加密**: OSS 服务端加密
- **敏感信息脱敏**: 分析结果中的敏感内容自动脱敏
- **数据备份**: 定期备份数据库和 OSS 文件

### 7.3 API 安全
- **Rate Limiting**: 使用 Redis 实现限流
- **CORS 配置**: 限制允许的域名
- **输入验证**: 使用 Pydantic 严格验证输入

## 8. 性能优化

### 8.1 后端优化
- **异步处理**: 所有 I/O 操作使用 async/await
- **数据库连接池**: SQLAlchemy 连接池配置
- **缓存策略**: 
  - Redis 缓存热点数据（用户状态、会话列表）
  - 分析结果缓存（相同 transcript_id 不重复分析）
- **CDN 加速**: 静态资源（Avatar 图片、动画）使用 CDN

### 8.2 前端优化
- **懒加载**: 列表项懒加载，只渲染可见区域
- **图片优化**: WebP 格式，响应式图片
- **代码分割**: 按路由分割代码，减少首屏加载时间

## 9. 监控和日志

### 9.1 日志系统
- **结构化日志**: 使用 JSON 格式，便于解析
- **日志级别**: DEBUG/INFO/WARNING/ERROR
- **日志聚合**: ELK Stack 收集和分析日志

### 9.2 监控指标
- **API 响应时间**: P50/P95/P99
- **错误率**: 4xx/5xx 错误统计
- **业务指标**: 
  - 每日活跃用户数
  - 录音会话数
  - 分析成功率
  - 压力桶触发次数

### 9.3 告警机制
- **错误告警**: 错误率超过阈值时告警
- **性能告警**: API 响应时间超过阈值时告警
- **业务告警**: 关键业务指标异常时告警

## 10. 部署方案

### 10.1 容器化部署
```dockerfile
# Dockerfile
FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://...
      - REDIS_URL=redis://...
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: work_survival
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

### 10.2 CI/CD 流程
1. **代码提交**: 推送到 GitHub
2. **自动测试**: GitHub Actions 运行单元测试和集成测试
3. **构建镜像**: 构建 Docker 镜像并推送到镜像仓库
4. **部署**: 自动部署到测试环境，手动审批后部署到生产环境

## 11. 开发计划 (Roadmap)

### Phase 1: 骨架搭建 (2-3周)
- [ ] 后端基础架构搭建（FastAPI + PostgreSQL + Redis）
- [ ] 音频上传和存储功能
- [ ] Gemini API 音频分析集成（已部分完成）
- [ ] 基础的任务列表和详情页
- [ ] 移动端基础框架（React Native/Flutter）
- [ ] 录音功能实现

### Phase 2: 核心功能 (3-4周)
- [ ] Gemini API 集成（对话分段、情绪分析）
- [ ] 策略建议生成（军师模式）
- [ ] 声纹识别和人物建档
- [ ] 任务详情页完整实现（分段展示、策略批注）
- [ ] 前端任务列表和详情页 UI

### Phase 3: 游戏化功能 (2-3周)
- [ ] 老黄牛 Avatar 状态系统
- [ ] 情绪压力桶计算和可视化
- [ ] "还回去"功能（嘴替 + 爆锤动效）
- [ ] 焚毁任务功能
- [ ] 3D 翻转效果（工作/生活模式切换）

### Phase 4: 优化和细节 (2周)
- [ ] 叹气检测优化
- [ ] 性能优化
- [ ] 监控和告警
- [ ] 用户体验优化
- [ ] 生活模式开发（二期）

## 12. 风险评估

### 12.1 技术风险
- **Gemini API 准确性**: 需要测试不同场景下的音频分析准确率（说话人识别、情绪分析等）
- **Gemini API 配额**: 免费层配额可能不足，需要监控使用量
- **声纹识别准确性**: 需要大量测试数据验证

### 12.2 业务风险
- **用户隐私**: 录音数据涉及隐私，需要严格的数据保护措施
- **内容合规**: 生成的内容需要符合法律法规
- **用户体验**: 游戏化设计可能不被所有用户接受

### 12.3 应对措施
- **技术风险**: 建立完善的测试体系，准备备用方案
- **业务风险**: 加强数据加密和访问控制，建立内容审核机制
- **用户体验**: 收集用户反馈，持续优化产品

## 13. 附录

### 13.1 API 端点汇总
- `/api/v1/audio/*` - 音频服务
- `/api/v1/analysis/*` - 分析服务
- `/api/v1/profile/*` - 档案服务
- `/api/v1/tasks/*` - 任务服务
- `/api/v1/status/*` - 状态服务
- `/ws/status/{user_id}` - WebSocket 实时状态

### 13.2 环境变量清单
```bash
# 数据库
DATABASE_URL=postgresql://user:password@localhost:5432/work_survival

# Redis
REDIS_URL=redis://localhost:6379/0

# Gemini API
GEMINI_API_KEY=your_api_key
PROXY_URL=http://47.79.254.213/secret-channel
USE_PROXY=true

# 阿里云 OSS（可选，用于音频文件持久化存储）
ALIYUN_ACCESS_KEY_ID=your_key_id
ALIYUN_ACCESS_KEY_SECRET=your_secret
ALIYUN_REGION=cn-shanghai
ALIYUN_OSS_BUCKET=work-survival-audio

# JWT
JWT_SECRET_KEY=your_secret_key
JWT_ALGORITHM=HS256

# 其他
ENVIRONMENT=development|production
LOG_LEVEL=INFO
```

---

**文档版本**: v1.0  
**最后更新**: 2026-01-03  
**维护者**: 开发团队

