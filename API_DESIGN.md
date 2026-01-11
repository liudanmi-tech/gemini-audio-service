# API 设计文档

## 1. 基础信息

### 1.1 Base URL
```
开发环境: http://localhost:8001
生产环境: https://api.worksurvival.com
```

### 1.2 认证方式
所有 API 请求需要在 Header 中携带 JWT Token：
```
Authorization: Bearer <jwt_token>
```

### 1.3 响应格式
所有 API 响应统一使用 JSON 格式：
```json
{
  "code": 200,
  "message": "success",
  "data": {...},
  "timestamp": "2026-01-03T10:30:00Z"
}
```

### 1.4 错误码
- `200`: 成功
- `400`: 请求参数错误
- `401`: 未授权
- `403`: 无权限
- `404`: 资源不存在
- `429`: 请求频率过高
- `500`: 服务器内部错误

## 2. 音频服务 API

### 2.1 上传音频文件
**POST** `/api/v1/audio/upload`

**请求**:
- Content-Type: `multipart/form-data`
- Body:
  - `file`: File (必需) - 音频文件 (mp3/wav/m4a, 最大 100MB)
  - `session_id`: String (可选) - 会话ID，用于继续之前的会话
  - `metadata`: JSON String (可选) - 元数据
    ```json
    {
      "device": "iPhone 15",
      "location": "会议室A",
      "tags": ["会议", "重要"]
    }
    ```

**响应**:
```json
{
  "code": 200,
  "message": "上传成功",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "audio_id": "660e8400-e29b-41d4-a716-446655440001",
    "upload_url": "oss://work-survival-audio/2026/01/03/audio_xxx.wav",
    "status": "uploaded",
    "estimated_duration": 300,
    "file_size": 5242880,
    "created_at": "2026-01-03T10:30:00Z"
  }
}
```

### 2.2 查询转写状态
**GET** `/api/v1/audio/{audio_id}/status`

**路径参数**:
- `audio_id`: UUID - 音频文件ID

**响应**:
```json
{
  "code": 200,
  "data": {
    "audio_id": "660e8400-e29b-41d4-a716-446655440001",
    "transcribe_status": "processing",
    "progress": 0.75,
    "transcript_id": "770e8400-e29b-41d4-a716-446655440002",
    "estimated_time_remaining": 30,
    "updated_at": "2026-01-03T10:35:00Z"
  }
}
```

**状态值**:
- `pending`: 等待处理
- `processing`: 处理中
- `completed`: 已完成
- `failed`: 处理失败

### 2.3 获取转写结果
**GET** `/api/v1/audio/{audio_id}/transcript`

**路径参数**:
- `audio_id`: UUID - 音频文件ID

**查询参数**:
- `format`: String (可选) - 返回格式，`full`(完整) 或 `simple`(简化)，默认 `full`

**响应**:
```json
{
  "code": 200,
  "data": {
    "transcript_id": "770e8400-e29b-41d4-a716-446655440002",
    "audio_id": "660e8400-e29b-41d4-a716-446655440001",
    "full_text": "完整转写文本...",
    "segment_count": 150,
    "speakers": ["speaker_1", "speaker_2", "speaker_3"],
    "segments": [
      {
        "segment_id": "880e8400-e29b-41d4-a716-446655440003",
        "start_time": 0.0,
        "end_time": 5.2,
        "text": "这段对话的具体内容",
        "speaker_id": "speaker_1",
        "confidence": 0.95,
        "cpm": 180
      }
    ],
    "created_at": "2026-01-03T10:40:00Z"
  }
}
```

## 3. 分析服务 API

### 3.1 分析音频会话
**POST** `/api/v1/analysis/analyze`

**请求体**:
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "transcript_id": "770e8400-e29b-41d4-a716-446655440002",
  "persona_mode": "veteran",
  "analysis_type": "full"
}
```

**参数说明**:
- `session_id`: UUID (必需) - 会话ID
- `transcript_id`: UUID (必需) - 转写结果ID
- `persona_mode`: String (可选) - 军师模式
  - `veteran`: 老油条模式
  - `newbie`: 小白兔模式
  - `strong`: 钮祜禄模式
  - `lying_flat`: 躺平模式
  - 默认: `veteran`
- `analysis_type`: String (可选) - 分析类型
  - `full`: 完整分析（包含所有对话和策略）
  - `quick`: 快速分析（仅摘要和情绪）
  - 默认: `full`

**响应**:
```json
{
  "code": 200,
  "data": {
    "analysis_id": "990e8400-e29b-41d4-a716-446655440004",
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "emotion_score": 60,
    "speaker_count": 3,
    "total_turns": 120,
    "sigh_count": 8,
    "sigh_timestamps": [45.2, 120.5, 180.3, 245.8, 300.1, 350.6, 420.3, 480.9],
    "segments": [
      {
        "segment_id": "aa0e8400-e29b-41d4-a716-446655440005",
        "title": "Q1预算讨论",
        "start_time": 0.0,
        "end_time": 320.0,
        "summary": "讨论Q1季度预算分配，涉及各部门资源协调",
        "emotion_tags": ["#PUA预警", "#急躁", "#画饼"],
        "strategy": {
          "type": "warning",
          "content": "老板正在施压，建议回复：'我需要先和团队确认一下具体数据，明天给您详细方案'",
          "tone": "diplomatic"
        },
        "risks": [
          "预算被大幅削减",
          "资源分配不公"
        ]
      }
    ],
    "dialogues": [
      {
        "dialogue_id": "bb0e8400-e29b-41d4-a716-446655440006",
        "segment_id": "aa0e8400-e29b-41d4-a716-446655440005",
        "speaker_id": "speaker_1",
        "speaker_name": "王总",
        "content": "这个季度的预算需要削减20%",
        "tone": "严肃",
        "timestamp": 10.5,
        "cpm": 200
      }
    ],
    "created_at": "2026-01-03T10:45:00Z"
  }
}
```

### 3.2 获取详细策略建议
**GET** `/api/v1/analysis/{analysis_id}/strategy`

**路径参数**:
- `analysis_id`: UUID - 分析结果ID

**查询参数**:
- `persona_mode`: String (可选) - 重新生成策略时使用的军师模式
- `segment_id`: UUID (可选) - 指定段落的ID，只返回该段落的策略

**响应**:
```json
{
  "code": 200,
  "data": {
    "analysis_id": "990e8400-e29b-41d4-a716-446655440004",
    "strategies": [
      {
        "segment_id": "aa0e8400-e29b-41d4-a716-446655440005",
        "context": "当前对话上下文：老板要求削减预算20%...",
        "suggestions": [
          {
            "type": "reply",
            "content": "我需要先和团队确认一下具体数据，明天给您详细方案",
            "reason": "使用拖字诀，争取时间思考对策",
            "tone": "diplomatic"
          },
          {
            "type": "action",
            "content": "准备数据支撑，列出削减预算的影响",
            "reason": "用数据说话，争取更多资源"
          }
        ]
      }
    ]
  }
}
```

## 4. 任务服务 API

### 4.1 获取任务列表
**GET** `/api/v1/tasks/sessions`

**查询参数**:
- `date`: String (可选) - 日期，格式 `YYYY-MM-DD`，默认今天
- `status`: String (可选) - 状态筛选
  - `recording`: 录制中
  - `analyzing`: 分析中
  - `archived`: 已归档
  - `burned`: 已焚毁
- `page`: Integer (可选) - 页码，默认 1
- `page_size`: Integer (可选) - 每页数量，默认 20，最大 100

**响应**:
```json
{
  "code": 200,
  "data": {
    "sessions": [
      {
        "session_id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Q1预算撕逼会",
        "start_time": "2026-01-03T10:30:00Z",
        "end_time": "2026-01-03T11:15:00Z",
        "duration": 2700,
        "tags": ["#PUA预警", "#急躁", "#画饼"],
        "status": "archived",
        "emotion_score": 60,
        "speaker_count": 3,
        "thumbnail_url": "https://cdn.example.com/thumbnails/session_xxx.jpg"
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 100,
      "total_pages": 5
    }
  }
}
```

### 4.2 获取任务详情
**GET** `/api/v1/tasks/sessions/{session_id}`

**路径参数**:
- `session_id`: UUID - 会话ID

**查询参数**:
- `include_transcript`: Boolean (可选) - 是否包含完整转写，默认 `false`
- `include_dialogues`: Boolean (可选) - 是否包含所有对话，默认 `true`

**响应**:
```json
{
  "code": 200,
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Q1预算撕逼会",
    "start_time": "2026-01-03T10:30:00Z",
    "end_time": "2026-01-03T11:15:00Z",
    "duration": 2700,
    "status": "archived",
    "metadata": {
      "device": "iPhone 15",
      "location": "会议室A"
    },
    "emotion_stats": {
      "score": 60,
      "total_turns": 120,
      "sigh_count": 8,
      "sigh_timestamps": [45.2, 120.5, 180.3, 245.8, 300.1, 350.6, 420.3, 480.9]
    },
    "segments": [
      {
        "segment_id": "aa0e8400-e29b-41d4-a716-446655440005",
        "title": "Q1预算讨论",
        "start_time": 0.0,
        "end_time": 320.0,
        "summary": "讨论Q1季度预算分配",
        "emotion_tags": ["#PUA预警", "#急躁"],
        "strategy": {
          "type": "warning",
          "content": "老板正在施压，建议回复：...",
          "tone": "diplomatic"
        },
        "risks": ["预算被大幅削减"]
      }
    ],
    "dialogues": [
      {
        "dialogue_id": "bb0e8400-e29b-41d4-a716-446655440006",
        "speaker_id": "speaker_1",
        "speaker_name": "王总",
        "content": "这个季度的预算需要削减20%",
        "tone": "严肃",
        "timestamp": 10.5,
        "cpm": 200
      }
    ],
    "analysis_id": "990e8400-e29b-41d4-a716-446655440004",
    "created_at": "2026-01-03T10:30:00Z",
    "updated_at": "2026-01-03T11:20:00Z"
  }
}
```

### 4.3 焚毁任务
**POST** `/api/v1/tasks/sessions/{session_id}/burn`

**路径参数**:
- `session_id`: UUID - 会话ID

**响应**:
```json
{
  "code": 200,
  "message": "任务已焚毁",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "burned",
    "burned_at": "2026-01-03T12:00:00Z"
  }
}
```

### 4.4 导出任务
**GET** `/api/v1/tasks/sessions/{session_id}/export`

**路径参数**:
- `session_id`: UUID - 会话ID

**查询参数**:
- `format`: String (必需) - 导出格式
  - `pdf`: PDF 格式
  - `txt`: 文本格式
  - `json`: JSON 格式

**响应**: 文件下载流

## 5. 档案服务 API

### 5.1 获取说话人列表
**GET** `/api/v1/profile/speakers`

**查询参数**:
- `status`: String (可选) - 筛选状态
  - `registered`: 已建档
  - `unregistered`: 未建档
  - 默认: 返回全部

**响应**:
```json
{
  "code": 200,
  "data": {
    "registered": [
      {
        "speaker_id": "cc0e8400-e29b-41d4-a716-446655440007",
        "name": "王总",
        "avatar": {
          "type": "周扒皮",
          "image_url": "https://cdn.example.com/avatars/zhoubapi.png"
        },
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
        "sample_audio_url": "https://cdn.example.com/samples/speaker_1_5s.wav",
        "sample_text": "这是一段5秒的音频采样文本"
      }
    ]
  }
}
```

### 5.2 注册说话人
**POST** `/api/v1/profile/speakers/register`

**请求体**:
```json
{
  "speaker_id": "speaker_1",
  "name": "王总",
  "avatar_type": "周扒皮",
  "sample_audio_segments": [
    "880e8400-e29b-41d4-a716-446655440003",
    "880e8400-e29b-41d4-a716-446655440004"
  ]
}
```

**参数说明**:
- `speaker_id`: String (必需) - ASR 返回的 speaker_cluster_id
- `name`: String (必需) - 说话人姓名
- `avatar_type`: String (可选) - 头像类型
  - `周扒皮`: 严厉型
  - `笑面虎`: 表面和善
  - `猪队友`: 不靠谱
  - `正常人`: 普通同事
- `sample_audio_segments`: Array[UUID] (可选) - 用于声纹注册的音频片段ID列表

**响应**:
```json
{
  "code": 200,
  "message": "注册成功",
  "data": {
    "speaker_id": "cc0e8400-e29b-41d4-a716-446655440007",
    "name": "王总",
    "voiceprint_id": "aliyun_voiceprint_12345",
    "status": "registered",
    "created_at": "2026-01-03T12:00:00Z"
  }
}
```

### 5.3 获取说话人详情
**GET** `/api/v1/profile/speakers/{speaker_id}`

**路径参数**:
- `speaker_id`: UUID - 说话人ID

**响应**:
```json
{
  "code": 200,
  "data": {
    "speaker_id": "cc0e8400-e29b-41d4-a716-446655440007",
    "name": "王总",
    "avatar": {
      "type": "周扒皮",
      "image_url": "https://cdn.example.com/avatars/zhoubapi.png"
    },
    "personality_analysis": {
      "tags": ["#D型人格", "#结果导向", "#喜怒无常"],
      "summary": "此人喜欢听数据，不喜欢听过程；周一心情通常不好。",
      "communication_style": "direct"
    },
    "interaction_history": {
      "total_sessions": 15,
      "total_duration": 7200,
      "emotion_trend": [
        {
          "date": "2026-01-01",
          "avg_emotion": 65,
          "session_count": 3
        },
        {
          "date": "2026-01-02",
          "avg_emotion": 45,
          "session_count": 2
        }
      ]
    },
    "audio_samples": [
      {
        "segment_id": "880e8400-e29b-41d4-a716-446655440003",
        "url": "https://cdn.example.com/samples/sample_1.wav",
        "duration": 5.0,
        "text": "采样文本内容"
      }
    ],
    "strategy_notes": "攻略笔记：与此人沟通时，多用数据说话，避免情绪化表达。周一避免提出新需求。",
    "created_at": "2026-01-01T10:00:00Z",
    "updated_at": "2026-01-03T12:00:00Z"
  }
}
```

### 5.4 验证声纹
**POST** `/api/v1/profile/speakers/{speaker_id}/voiceprint/verify`

**路径参数**:
- `speaker_id`: UUID - 说话人ID

**请求体**:
```json
{
  "audio_segment_id": "880e8400-e29b-41d4-a716-446655440003"
}
```

**响应**:
```json
{
  "code": 200,
  "data": {
    "matched": true,
    "confidence": 0.92,
    "speaker_id": "cc0e8400-e29b-41d4-a716-446655440007",
    "speaker_name": "王总"
  }
}
```

## 6. 状态服务 API

### 6.1 获取 Avatar 状态
**GET** `/api/v1/status/avatar`

**响应**:
```json
{
  "code": 200,
  "data": {
    "avatar_state": "normal",
    "avatar_image_url": "https://cdn.example.com/avatars/ox_normal.png",
    "pressure_level": 0.75,
    "pressure_bucket": {
      "current": 75,
      "max": 100,
      "can_vent": true
    },
    "stats": {
      "today_sessions": 5,
      "today_emotion_avg": 55,
      "today_sigh_count": 12,
      "burned_tasks_today": 2,
      "total_merit": 10,
      "total_health": 8
    },
    "updated_at": "2026-01-03T12:00:00Z"
  }
}
```

**Avatar 状态值**:
- `good`: 状态好（戴墨镜，喝咖啡）
- `normal`: 平常（机械敲键盘）
- `bad`: 比较丧（趴在地上，头顶乌云）

### 6.2 触发"还回去"宣泄
**POST** `/api/v1/status/vent`

**请求体**:
```json
{
  "vent_type": "both"
}
```

**参数说明**:
- `vent_type`: String (可选) - 宣泄类型
  - `mouth_replacement`: 仅嘴替
  - `physical_venting`: 仅爆锤
  - `both`: 两者都有
  - 默认: `both`

**响应**:
```json
{
  "code": 200,
  "message": "宣泄成功",
  "data": {
    "vent_id": "dd0e8400-e29b-41d4-a716-446655440008",
    "mouth_replacement": {
      "content": "这破班一秒都不想上了！",
      "bullet_comments": [
        "画饼充饥，老板你吃了吗？",
        "这破班一秒都不想上了！",
        "周一就想请假！"
      ]
    },
    "physical_venting": {
      "animation_sequence": ["transform", "punch_1", "punch_2", "reset"],
      "haptic_pattern": [100, 200, 300, 400],
      "duration": 2000
    },
    "rewards": [
      {
        "type": "merit",
        "value": 1,
        "name": "功德+1"
      },
      {
        "type": "health",
        "value": 1,
        "name": "乳腺通畅+1"
      }
    ],
    "pressure_before": 0.75,
    "pressure_after": 0.0,
    "created_at": "2026-01-03T12:05:00Z"
  }
}
```

### 6.3 获取状态历史
**GET** `/api/v1/status/history`

**查询参数**:
- `days`: Integer (可选) - 查询天数，默认 7 天，最大 30 天

**响应**:
```json
{
  "code": 200,
  "data": {
    "history": [
      {
        "date": "2026-01-01",
        "emotion_score": 65,
        "pressure_level": 0.5,
        "sessions_count": 3,
        "vent_count": 1,
        "burned_tasks_count": 0
      },
      {
        "date": "2026-01-02",
        "emotion_score": 45,
        "pressure_level": 0.8,
        "sessions_count": 5,
        "vent_count": 2,
        "burned_tasks_count": 1
      }
    ]
  }
}
```

## 7. WebSocket API

### 7.1 实时状态更新
**WebSocket** `/ws/status/{user_id}`

**连接**:
```javascript
const ws = new WebSocket('ws://api.example.com/ws/status/user_id');
```

**消息格式**:
```json
{
  "type": "status_update",
  "data": {
    "avatar_state": "normal",
    "pressure_level": 0.75,
    "pressure_bucket": {
      "current": 75,
      "max": 100,
      "can_vent": true
    }
  },
  "timestamp": "2026-01-03T12:00:00Z"
}
```

**消息类型**:
- `status_update`: 状态更新
- `session_progress`: 会话处理进度
- `analysis_complete`: 分析完成通知

## 8. 错误响应示例

### 8.1 参数错误
```json
{
  "code": 400,
  "message": "请求参数错误",
  "errors": [
    {
      "field": "file",
      "message": "文件大小不能超过 100MB"
    }
  ],
  "timestamp": "2026-01-03T12:00:00Z"
}
```

### 8.2 未授权
```json
{
  "code": 401,
  "message": "未授权，请先登录",
  "timestamp": "2026-01-03T12:00:00Z"
}
```

### 8.3 资源不存在
```json
{
  "code": 404,
  "message": "会话不存在",
  "timestamp": "2026-01-03T12:00:00Z"
}
```

### 8.4 服务器错误
```json
{
  "code": 500,
  "message": "服务器内部错误",
  "error_id": "err_123456789",
  "timestamp": "2026-01-03T12:00:00Z"
}
```

## 9. 限流规则

- **普通 API**: 100 请求/分钟/用户
- **上传 API**: 10 请求/分钟/用户
- **分析 API**: 5 请求/分钟/用户
- **WebSocket**: 无限制

超过限制时返回 `429` 错误：
```json
{
  "code": 429,
  "message": "请求频率过高",
  "retry_after": 60,
  "timestamp": "2026-01-03T12:00:00Z"
}
```

## 10. 版本控制

API 版本通过 URL 路径控制：
- `/api/v1/*` - 当前版本
- `/api/v2/*` - 未来版本

旧版本 API 将在新版本发布后保留 6 个月，然后废弃。

---

**文档版本**: v1.0  
**最后更新**: 2026-01-03


