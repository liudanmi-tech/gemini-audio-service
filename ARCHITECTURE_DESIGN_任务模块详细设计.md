# 任务模块详细设计文档

## 1. 模块概述

### 1.1 功能定位
任务模块是"职场生存指南"的核心功能模块，用户通过录制会议音频，系统自动分析并生成任务记录，帮助用户识别职场风险、记录重要对话、管理会议档案。

### 1.2 核心流程
```
用户录制音频 → 上传到服务端 → Gemini 分析 → 生成任务记录 → 展示分析结果
```

---

## 2. 完整数据流程

### 2.1 录制阶段
```
iOS 客户端
  ↓
1. 用户点击录制按钮
  ↓
2. AVAudioRecorder 开始录音
  ↓
3. 实时显示录音时长
  ↓
4. 用户停止录制
  ↓
5. 生成音频文件（m4a 格式）
  ↓
6. 准备上传
```

### 2.2 上传阶段
```
iOS 客户端
  ↓
POST /api/v1/audio/upload
  - file: 音频文件
  - metadata: 元数据（可选）
  ↓
后端服务
  ↓
1. 接收音频文件
  ↓
2. 验证文件格式和大小
  ↓
3. 创建任务记录（状态：analyzing）
  ↓
4. 返回 session_id 和 audio_id
  ↓
5. 异步调用 Gemini API 分析
  ↓
响应：
{
  "session_id": "uuid",
  "audio_id": "uuid",
  "status": "analyzing",
  "estimated_duration": 300
}
```

### 2.3 分析阶段（异步）
```
后端服务
  ↓
1. 上传音频文件到 Gemini
  ↓
2. 等待文件处理完成（ACTIVE 状态）
  ↓
3. 调用 Gemini 模型分析
  ↓
4. 解析分析结果：
   - speaker_count: 说话人数
   - dialogues: 对话列表（说话人、内容、语气）
   - risks: 风险点列表
  ↓
5. 计算情绪分数
  ↓
6. 更新任务记录：
   - 状态：analyzing → archived
   - 填充分析结果
   - 生成标签
  ↓
7. 通知客户端（可选：WebSocket 推送）
```

### 2.4 展示阶段
```
iOS 客户端
  ↓
1. 轮询或接收推送，获取分析结果
  ↓
2. 更新任务列表中的任务状态
  ↓
3. 用户点击任务卡片
  ↓
4. 显示任务详情：
   - 基本信息（标题、时间、时长）
   - 分析结果（说话人数、情绪分数）
   - 对话列表（可展开查看）
   - 风险点列表
   - 标签
```

---

## 3. API 接口设计

### 3.1 上传音频接口

**POST** `/api/v1/audio/upload`

**请求**:
- Content-Type: `multipart/form-data`
- Body:
  - `file`: File (必需) - 音频文件 (m4a/mp3/wav, 最大 100MB)
  - `title`: String (可选) - 任务标题，默认使用时间戳
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
    "title": "录音 14:30",
    "status": "analyzing",
    "estimated_duration": 300,
    "created_at": "2026-01-03T14:30:00Z"
  }
}
```

### 3.2 获取任务列表接口

**GET** `/api/v1/tasks/sessions`

**查询参数**:
- `page`: Int (可选, 默认 1) - 页码
- `page_size`: Int (可选, 默认 20) - 每页数量
- `date`: String (可选) - 日期筛选，格式：YYYY-MM-DD
- `status`: String (可选) - 状态筛选：recording|analyzing|archived|burned

**响应**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "sessions": [
      {
        "session_id": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Q1预算撕逼会",
        "start_time": "2026-01-03T14:30:00Z",
        "end_time": "2026-01-03T15:30:00Z",
        "duration": 3600,
        "tags": ["#PUA预警", "#急躁", "#画饼"],
        "status": "archived",
        "emotion_score": 60,
        "speaker_count": 3
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 10,
      "total_pages": 1
    }
  }
}
```

### 3.3 获取任务详情接口

**GET** `/api/v1/tasks/sessions/{session_id}`

**路径参数**:
- `session_id`: UUID - 任务ID

**响应**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Q1预算撕逼会",
    "start_time": "2026-01-03T14:30:00Z",
    "end_time": "2026-01-03T15:30:00Z",
    "duration": 3600,
    "tags": ["#PUA预警", "#急躁", "#画饼"],
    "status": "archived",
    "emotion_score": 60,
    "speaker_count": 3,
    "dialogues": [
      {
        "speaker": "说话人1",
        "content": "这个预算我们需要再讨论一下",
        "tone": "平静",
        "timestamp": 10.5
      },
      {
        "speaker": "说话人2",
        "content": "我觉得这个预算不合理",
        "tone": "愤怒",
        "timestamp": 25.3
      }
    ],
    "risks": [
      "预算争议可能导致项目延期",
      "团队关系紧张"
    ],
    "created_at": "2026-01-03T14:30:00Z",
    "updated_at": "2026-01-03T14:35:00Z"
  }
}
```

### 3.4 查询分析状态接口

**GET** `/api/v1/tasks/sessions/{session_id}/status`

**路径参数**:
- `session_id`: UUID - 任务ID

**响应**:
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "analyzing",
    "progress": 0.75,
    "estimated_time_remaining": 30,
    "updated_at": "2026-01-03T14:33:00Z"
  }
}
```

---

## 4. 数据库设计

### 4.1 任务表 (sessions)

```sql
CREATE TABLE sessions (
    session_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(255) NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    duration INTEGER NOT NULL,  -- 秒
    status VARCHAR(20) NOT NULL,  -- recording|analyzing|archived|burned
    emotion_score INTEGER,  -- 0-100
    speaker_count INTEGER,
    audio_id VARCHAR(255),  -- Gemini 文件 ID
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sessions_status ON sessions(status);
CREATE INDEX idx_sessions_start_time ON sessions(start_time DESC);
CREATE INDEX idx_sessions_created_at ON sessions(created_at DESC);
```

### 4.2 对话表 (dialogues)

```sql
CREATE TABLE dialogues (
    dialogue_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    speaker VARCHAR(50) NOT NULL,
    content TEXT NOT NULL,
    tone VARCHAR(50),
    timestamp REAL,  -- 秒
    sequence_order INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dialogues_session_id ON dialogues(session_id);
CREATE INDEX idx_dialogues_sequence ON dialogues(session_id, sequence_order);
```

### 4.3 风险点表 (risks)

```sql
CREATE TABLE risks (
    risk_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    risk_content TEXT NOT NULL,
    risk_level VARCHAR(20),  -- low|medium|high
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_risks_session_id ON risks(session_id);
```

### 4.4 标签表 (tags)

```sql
CREATE TABLE tags (
    tag_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(session_id) ON DELETE CASCADE,
    tag_name VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tags_session_id ON tags(session_id);
CREATE INDEX idx_tags_name ON tags(tag_name);
```

---

## 5. 后端实现要点

### 5.1 音频上传处理

```python
@app.post("/api/v1/audio/upload")
async def upload_audio(
    file: UploadFile = File(...),
    title: Optional[str] = None,
    metadata: Optional[str] = None
):
    # 1. 验证文件
    # 2. 创建任务记录（状态：analyzing）
    # 3. 保存音频文件（临时存储或 OSS）
    # 4. 异步调用分析任务
    # 5. 返回 session_id
    pass
```

### 5.2 异步分析任务

```python
@celery.task
async def analyze_audio_task(session_id: str, audio_file_path: str):
    # 1. 上传音频到 Gemini
    # 2. 等待文件处理完成
    # 3. 调用 Gemini 模型分析
    # 4. 解析分析结果
    # 5. 保存到数据库
    # 6. 更新任务状态：analyzing → archived
    pass
```

### 5.3 任务列表查询

```python
@app.get("/api/v1/tasks/sessions")
async def get_task_list(
    page: int = 1,
    page_size: int = 20,
    date: Optional[str] = None,
    status: Optional[str] = None
):
    # 1. 构建查询条件
    # 2. 分页查询
    # 3. 返回任务列表
    pass
```

### 5.4 任务详情查询

```python
@app.get("/api/v1/tasks/sessions/{session_id}")
async def get_task_detail(session_id: str):
    # 1. 查询任务基本信息
    # 2. 查询对话列表
    # 3. 查询风险点列表
    # 4. 查询标签列表
    # 5. 组装返回数据
    pass
```

---

## 6. iOS 客户端实现要点

### 6.1 录制功能

```swift
// RecordingViewModel.swift
func stopRecordingAndUpload() {
    guard let audioURL = audioRecorder.stopRecording() else { return }
    
    isUploading = true
    
    Task {
        do {
            let response = try await networkManager.uploadAudio(
                fileURL: audioURL,
                title: nil
            )
            
            // 创建新任务并添加到列表
            let newTask = TaskItem(
                id: response.sessionId,
                title: response.title,
                startTime: Date(),
                endTime: nil,
                duration: Int(recordingTime),
                tags: [],
                status: .analyzing,
                emotionScore: nil,
                speakerCount: nil
            )
            
            await MainActor.run {
                // 添加到列表
                NotificationCenter.default.post(
                    name: NSNotification.Name("NewTaskCreated"),
                    object: newTask
                )
                
                // 开始轮询状态
                startPollingStatus(sessionId: response.sessionId)
            }
        } catch {
            // 处理错误
        }
    }
}
```

### 6.2 状态轮询

```swift
func startPollingStatus(sessionId: String) {
    Task {
        while true {
            do {
                let status = try await networkManager.getTaskStatus(sessionId: sessionId)
                
                if status.status == "archived" {
                    // 分析完成，获取详情并更新
                    let detail = try await networkManager.getTaskDetail(sessionId: sessionId)
                    
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TaskAnalysisCompleted"),
                            object: detail
                        )
                    }
                    break
                }
                
                // 等待 3 秒后再次查询
                try await Task.sleep(nanoseconds: 3_000_000_000)
            } catch {
                break
            }
        }
    }
}
```

### 6.3 任务列表

```swift
// TaskListViewModel.swift
func loadTasks() {
    Task {
        do {
            let response = try await networkManager.getTaskList()
            await MainActor.run {
                self.tasks = response.sessions
                self.isLoading = false
            }
        } catch {
            // 处理错误
        }
    }
}
```

### 6.4 任务详情

```swift
// TaskDetailViewModel.swift
func loadTaskDetail(sessionId: String) {
    Task {
        do {
            let detail = try await networkManager.getTaskDetail(sessionId: sessionId)
            await MainActor.run {
                self.task = detail
                self.isLoading = false
            }
        } catch {
            // 处理错误
        }
    }
}
```

---

## 7. 关键技术点

### 7.1 异步处理
- 音频分析是耗时操作，必须异步处理
- 使用 Celery 任务队列，避免阻塞 API
- 客户端使用轮询或 WebSocket 获取状态更新

### 7.2 错误处理
- 文件上传失败：重试机制
- Gemini API 调用失败：重试 + 降级处理
- 分析超时：设置超时时间，返回部分结果

### 7.3 性能优化
- 音频文件压缩：客户端上传前压缩
- 分页加载：任务列表分页，避免一次性加载过多
- 缓存策略：分析结果缓存，避免重复分析

### 7.4 数据一致性
- 任务状态更新使用事务
- 分析结果保存时检查任务状态
- 客户端轮询时处理并发更新

---

## 8. 测试要点

### 8.1 功能测试
- [ ] 录制音频并上传
- [ ] 任务列表正确显示
- [ ] 分析状态正确更新
- [ ] 任务详情正确显示
- [ ] 对话列表正确展示
- [ ] 风险点正确识别

### 8.2 性能测试
- [ ] 大文件上传（50MB+）
- [ ] 长时间音频分析（30分钟+）
- [ ] 并发上传（多个用户同时上传）
- [ ] 列表加载性能（100+ 任务）

### 8.3 异常测试
- [ ] 网络中断处理
- [ ] 服务端错误处理
- [ ] Gemini API 失败处理
- [ ] 文件格式错误处理

---

## 9. 后续优化方向

### 9.1 实时推送
- 使用 WebSocket 推送分析状态更新
- 减少客户端轮询，提升用户体验

### 9.2 离线支持
- 客户端缓存任务列表
- 离线录制，网络恢复后自动上传

### 9.3 批量处理
- 支持批量上传多个音频文件
- 批量分析，提升效率

### 9.4 智能标签
- 基于分析结果自动生成标签
- 支持自定义标签

---

## 10. 部署检查清单

### 10.1 后端部署
- [ ] FastAPI 服务正常运行
- [ ] 数据库连接正常
- [ ] Gemini API 配置正确
- [ ] Celery 任务队列正常
- [ ] Nginx 反向代理配置正确

### 10.2 客户端配置
- [ ] API 地址配置正确
- [ ] 网络请求正常
- [ ] 错误处理完善
- [ ] 状态更新正常

---

**文档版本**: v1.0  
**最后更新**: 2026-01-07  
**维护者**: 开发团队

