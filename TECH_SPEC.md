# WorkSurvivalGuide 技术方案

> 最后更新：2026-04-15

---

## 一、整体架构

```
iOS App
  │
  ├── 读请求 → Beijing server (123.57.29.111:8000)   只读副本
  └── 写请求 → Singapore server (47.79.254.213:80)   主服务（Nginx → uvicorn :8000）
                        │
                        └── PostgreSQL (Aliyun RDS, 北京)
                            gemini_audio_db
```

**服务器访问**
- Singapore：`ssh gemini-server`（id_rsa 密钥，user=admin）
- Beijing：`sshpass -p 'LD123456zhoudabao' ssh root@123.57.29.111`（密码登录，user=root）
- DB 连接：`pgm-2ze5w19pz5t064k04o.pg.rds.aliyuncs.com`，user `zhoudabao888`，db `gemini_audio_db`

---

## 二、后端服务（Singapore server）

### 核心文件

| 文件 | 作用 |
|------|------|
| `main.py` | FastAPI 主服务，全部 API 端点 |
| `skills/ios_skill_registry.py` | iOS 43 个子技能定义、6 大分类、prompt 模板 |
| `skills/router.py` | 技能匹配引擎 `match_skills_v2()` |
| `database/models.py` | SQLAlchemy ORM 模型 |
| `services/memory_service.py` | 跨会话记忆检索 |
| `scene_image_generator.py` | 场景图片并行生成 |

### 录音分析流程

```
POST /audio/upload
  → 语音转录（Gemini）
  → 声纹识别 + 档案匹配
  → conversation_summary 写入
  → 记忆钩子 (add_memory)
  → session.status = completed
  → 异步触发 _generate_strategies_core()
       ├── match_skills_v2() → 技能 stubs
       ├── asyncio.create_task(scene_image_generator)   并行生成场景图
       ├── 并行执行 execute_now stubs（emotion / depression 等 always_run 技能）
       ├── pending stubs → 标记 is_pending=True，不执行
       └── 写入 StrategyAnalysis（skill_cards + scene_images）
```

### 技能匹配 v2（Skill Matching v2）

**iOS 6 大类（43 个子技能）**

| 分类 | 代表技能 |
|------|---------|
| `work_life` | 薪资谈判、远程办公、职场冲突、上司沟通 等 |
| `campus_life` | 教授邮件、室友矛盾、学业压力、留学适应 等 |
| `relationships` | 分手、社交焦虑、伴侣沟通、友谊维护 等 |
| `family` | 移民家庭、愤怒管理、育儿压力、原生家庭 等 |
| `personal_growth` | 倦怠恢复、拖延、批评处理、自我价值 等 |
| `life_skills` | 房东沟通、金钱对话、医疗权益、邻里冲突 等 |

**Stub 数据格式**（`match_skills_v2()` 返回值）

```json
{
  "skill_id": "salary_negotiation",
  "skill_name": "Salary Negotiation",
  "category": "work_life",
  "score": 85,
  "is_custom": false,
  "exec_template": "",
  "exec_context": {},
  "execute_now": false,
  "always_run": false,
  "content_type": "strategy"
}
```

**iOS skill ID → 服务端 DB skill ID 映射**（`get_server_skill_id_for_exec()`）

```
salary_negotiation      → workplace_scenario
partner_communication   → family_relationship
campus_life / life_skills 技能 → 内联 prompt 模板（不查 DB）
emotion_recognition     → 直接查 DB
depression_prevention   → 直接查 DB
```

### Skill Card 格式（写入 `strategy_analysis.skill_cards`）

```json
{
  "skill_id": "anger_management",
  "skill_name": "Anger Management",
  "content_type": "strategy | emotion | mental_health | pending",
  "category": "work_life",
  "score": 72,
  "is_custom": false,
  "dimension": "",
  "matched_sub_skill": "",
  "content": { ... }
}
```

### 关键 API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/v1/audio/upload` | 上传录音，触发分析 |
| GET | `/api/v1/tasks/sessions/{id}/status` | 轮询分析状态 |
| POST | `/api/v1/tasks/sessions/{id}/strategies` | 获取 / 触发策略分析 |
| POST | `/api/v1/sessions/{id}/skills/{skill_id}/execute` | 按需执行 pending 技能（全量 JSON 返回） |
| POST | `/api/v1/sessions/{id}/skills/{skill_id}/execute/stream` | SSE 流式执行 pending 技能（纯文本） |
| POST | `/api/v1/auth/login` | 手机号登录 |
| GET | `/api/v1/auth/me` | 当前用户信息 |

### SSE 流式端点格式

```
# 服务端推送格式
data: <文字片段>\n\n
data: [DONE]\n\n
data: [ERROR] <错误信息>\n\n

# 换行符转义：\n → \\n（客户端解析时还原）
```

### 已知 Bug 修复记录

- **skill_executions FK 违反**：iOS skill ID（如 `remote_work`）不在 `skills` 表 → 修复方案：用 `begin_nested()` savepoint 隔离写入，同时通过 `get_server_skill_id_for_exec()` 将 iOS ID 映射为服务端 ID 再写 `skill_executions`

---

## 三、iOS 客户端

### 关键文件

| 文件 | 作用 |
|------|------|
| `Models/VisualData.swift` | 数据模型（SkillCard、SceneImage、StrategyAnalysisResponse 等） |
| `Views/StrategyAnalysisView_Updated.swift` | 策略分析展示页（手风琴 + Tab） |
| `Services/NetworkManager.swift` | 所有 API 调用 |
| `Shared/AppConfig.swift` | `useBeijingRead`、读写 baseURL 配置 |

读接口走北京：`useBeijingRead = true`，写接口始终走新加坡。

### SkillCard 数据模型

```swift
struct SkillCard: Codable, Identifiable {
    let skillId: String
    let skillName: String
    let contentType: String   // strategy | emotion | mental_health | pending
    let category: String?     // work_life | campus_life | relationships | family | personal_growth | life_skills
    let score: Int?           // 0-100，匹配分数
    let isCustom: Bool?       // 是否自定义技能
    let dimension: String?
    let matchedSubSkill: String?
    let content: SkillCardContent?
}
```

**sceneCategory 计算属性**（用于 Tab 分组）

```
work_life       → "Work Life"
campus_life     → "Campus"
relationships   → "Social"
family          → "Family"
personal_growth → "Growth"
life_skills     → "Life"
always / 未知   → ""（由 SkillCardsTabView 注入第一 Tab 最前）
```

### 策略分析页 UI 结构

```
StrategyAnalysisView_Updated
  ├── SceneRestoreImageCarouselView（场景图片横向滑动）
  └── SkillCardsTabView
        ├── SceneTabBar（Work Life / Campus / Social / Family / Growth / Life）
        │     首 Tab 前置所有 always_run 卡片（emotion / mental_health）
        └── SkillAccordionPanel × N
              ├── 普通卡片：EmotionCardView / MentalHealthCardView / StrategyCardContent
              └── Pending 卡片：点击 "Analyze Now" → SSE 流式逐字输出
```

### SSE 流式执行（客户端实现）

```swift
// NetworkManager.executeSkillStream()
// 底层：URLSession.bytes(for:) + asyncBytes.lines
// 解析：
//   "data: <text>" → replacingOccurrences("\\n", "\n") → onChunk(text)
//   "data: [DONE]" → onDone()
//   "data: [ERROR] ..." → onError(msg)
// 所有回调均在主线程执行（await MainActor.run）
```

### SceneImage 场景图片

- 由 `scene_image_generator.py` 与技能分析并行生成（`asyncio.create_task()`）
- index 从 1000 起，避免与技能 visual 图冲突
- iOS 通过图片代理 URL 访问（OSS 私有 bucket → 后端 `/api/v1/images/{session}/{index}`）

---

## 四、数据库关键表

| 表 | 关键字段 |
|----|---------|
| `sessions` | `id, user_id, status(analyzing/completed/archived), image_status(pending/generating/completed/failed)` |
| `analysis_results` | `session_id, transcript(JSONB), summary, conversation_summary, speaker_mapping` |
| `strategy_analysis` | `session_id, skill_cards(JSONB), scene_images(JSONB), scene_category, scene_confidence` |
| `skills` | `skill_id(PK), name, category, prompt_template` |
| `skill_executions` | `session_id, skill_id(FK→skills), scene_category, confidence_score, execution_time_ms, success` |
| `custom_skills` | `id, user_id, name, markdown_content` |
| `profiles` | `id, user_id, name, relationship`（声纹档案） |
| `users` | `id, phone, created_at, last_login_at` |

---

## 五、待完成 / 已知限制

| 项目 | 状态 | 说明 |
|------|------|------|
| Beijing 服务器未同步 skill matching v2 | 未完成 | 仅影响旧数据读取展示，新策略分析在 Singapore 生成 |
| 旧 session skill_cards 无 `score`/`is_custom` 字段 | 已兼容 | iOS 侧字段定义为可选，nil 安全 |
| Apple Sign In + Email 密码登录 | 未实施 | App Store 上线前需完成，方案已设计 |
| 登录注册页隐私协议入口 | 未实施 | App Store 4.8 审核要求，随 Auth 改造一并实施 |
