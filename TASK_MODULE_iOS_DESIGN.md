# 任务模块 (副本) - iOS 技术方案详细设计

## 📋 目录
1. [模块概述](#模块概述)
2. [iOS 开发基础准备](#ios-开发基础准备)
3. [功能需求分析](#功能需求分析)
4. [技术架构设计](#技术架构设计)
5. [UI/UX 设计](#uiux-设计)
6. [数据模型设计](#数据模型设计)
7. [核心功能实现](#核心功能实现)
8. [API 接口设计](#api-接口设计)
9. [开发步骤详解](#开发步骤详解)
10. [常见问题解答](#常见问题解答)

---

## 1. 模块概述

### 1.1 模块定位
**任务模块**是 APP 的核心功能模块，位于底部 Tab 的第一个位置。用户可以在这里：
- 📹 录制会议/对话音频
- 📝 查看所有录音任务列表
- 🔍 查看任务详情（对话内容、情绪分析、策略建议）
- 🔥 焚毁不想要的任务

### 1.2 用户流程
```
打开 APP → 进入任务 Tab → 看到任务列表
    ↓
点击录制按钮 → 开始录音 → 停止录音 → 自动上传分析
    ↓
返回任务列表 → 看到新任务（分析中） → 等待完成
    ↓
点击任务卡片 → 查看详情 → 阅读对话和策略 → 可选：焚毁任务
```

---

## 2. iOS 开发基础准备

### 2.1 开发环境要求
- **macOS**: macOS 13.0 或更高版本
- **Xcode**: 15.0 或更高版本
- **iOS 部署目标**: iOS 16.0+
- **Swift 版本**: Swift 5.9+
- **开发语言**: Swift（纯原生，不使用 Objective-C）

### 2.2 项目创建步骤

#### 步骤 1: 创建新项目
1. 打开 Xcode
2. 选择 `File` → `New` → `Project`
3. 选择 `iOS` → `App`
4. 填写项目信息：
   - **Product Name**: WorkSurvivalGuide
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: 选择 Core Data（如果需要本地缓存）

#### 步骤 2: 配置项目设置
1. 在项目设置中，设置 **Deployment Target** 为 iOS 16.0
2. 在 **Info.plist** 中添加权限说明：
   ```xml
   <key>NSMicrophoneUsageDescription</key>
   <string>需要访问麦克风以录制会议音频</string>
   ```

### 2.3 需要安装的第三方库（通过 Swift Package Manager）

在 Xcode 中：`File` → `Add Package Dependencies...`

**必需库**:
- **Alamofire** (5.8+): 网络请求库
  - URL: `https://github.com/Alamofire/Alamofire.git`
- **Kingfisher** (7.0+): 图片加载和缓存（如果需要显示头像）
  - URL: `https://github.com/onevcat/Kingfisher.git`

**可选库**:
- **Lottie** (4.0+): 动画效果（用于焚毁动效）
  - URL: `https://github.com/airbnb/lottie-ios.git`

---

## 3. 功能需求分析

### 3.1 任务列表页（首页）

#### 功能点 1: 任务卡片展示
- **展示内容**:
  - 任务标题（自动生成，如"Q1预算撕逼会"）
  - 时间范围（如"10:30 - 11:15"）
  - 时长（如"45分钟"）
  - 情绪标签（如 `#PUA预警` `#急躁` `#画饼`）
  - 状态指示器（🔴录制中 / 🟡分析中 / 🟢已归档）

#### 功能点 2: 按天聚合
- 任务按日期分组显示
- 每天一个分组，显示日期（如"今天"、"昨天"、"2026-01-02"）
- 每个分组下显示该天的所有任务

#### 功能点 3: 悬浮录制按钮
- 底部中央固定一个红色大按钮
- 点击开始录音，再次点击停止录音
- 录制时按钮有呼吸闪烁动画
- 录制时显示录音时长

### 3.2 任务详情页

#### 功能点 1: 顶部战斗结算条
- **情绪分数**: 显示今日上班心情打分（0-100分）
- **输出统计**: 显示说话轮数（如"你输出了 120 句"）
- **叹气监测**: 显示叹气次数（如"监测到叹息 8 次"），点击可跳转到对应时间点

#### 功能点 2: 分段式对话流
- 不显示流水账，而是智能分段
- 每个段落（Block）包含：
  - **主题摘要**: 一句话总结这段在讨论什么
  - **时间区间**: 如 `00:00 - 05:20`
  - **核心批注**: 像便利贴一样贴在旁边，显示策略建议
  - **展开按钮**: 点击可查看该段落的详细对话

#### 功能点 3: 底部交互栏
- **原文开关**: 切换"仅看总结"和"看逐字稿"
- **人物筛选**: 显示所有说话人的头像，点击某个头像只高亮该人说的话
- **焚毁按钮**: 点击后出现火焰动效，任务被删除

### 3.3 录制中状态

#### 功能点 1: 锁屏显示
- 录制时，锁屏界面显示"正在监测老板画饼中..."
- 使用 iOS 的 Live Activities 功能

#### 功能点 2: 实时反馈
- 检测到叹气时，屏幕边缘泛起红光
- 提示"收到叹息，转化为怒气值 +1"

---

## 4. 技术架构设计

### 4.1 架构模式：MVVM

```
┌─────────────┐
│    View     │  (SwiftUI Views)
│  (UI层)     │
└──────┬──────┘
       │ @State / @ObservedObject
       ▼
┌─────────────┐
│  ViewModel  │  (ObservableObject)
│  (逻辑层)   │
└──────┬──────┘
       │ 调用
       ▼
┌─────────────┐
│   Service   │  (网络请求、数据管理)
│  (服务层)   │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────┐
│   Backend   │  (FastAPI 后端)
│    API      │
└─────────────┘
```

### 4.2 文件结构

```
WorkSurvivalGuide/
├── App/
│   ├── WorkSurvivalGuideApp.swift      # App 入口
│   └── ContentView.swift                # 主视图（TabView）
│
├── TaskModule/                          # 任务模块
│   ├── Views/
│   │   ├── TaskListView.swift          # 任务列表页
│   │   ├── TaskDetailView.swift        # 任务详情页
│   │   ├── Components/
│   │   │   ├── TaskCardView.swift      # 任务卡片组件
│   │   │   ├── SegmentBlockView.swift  # 对话段落组件
│   │   │   └── RecordingButtonView.swift # 录制按钮组件
│   │
│   ├── ViewModels/
│   │   ├── TaskListViewModel.swift     # 任务列表 ViewModel
│   │   ├── TaskDetailViewModel.swift   # 任务详情 ViewModel
│   │   └── RecordingViewModel.swift    # 录制 ViewModel
│   │
│   ├── Models/
│   │   ├── Task.swift                  # 任务数据模型
│   │   ├── Segment.swift               # 对话段落模型
│   │   └── Dialogue.swift              # 对话模型
│   │
│   └── Services/
│       ├── AudioRecorderService.swift   # 录音服务
│       ├── APIService.swift             # API 请求服务
│       └── FileUploadService.swift      # 文件上传服务
│
├── Shared/                              # 共享组件
│   ├── Models/
│   │   └── APIResponse.swift           # API 响应模型
│   └── Utilities/
│       └── NetworkManager.swift        # 网络管理器
```

---

## 5. UI/UX 设计

### 5.1 任务列表页 UI 设计

#### 布局结构
```
┌─────────────────────────────────┐
│  Navigation Bar                 │
│  "任务 (副本)"                   │
├─────────────────────────────────┤
│                                 │
│  ┌─ 今天 ───────────────────┐   │
│  │                         │   │
│  │  ┌───────────────────┐   │   │
│  │  │ 任务卡片 1       │   │   │
│  │  └───────────────────┘   │   │
│  │                         │   │
│  │  ┌───────────────────┐   │   │
│  │  │ 任务卡片 2       │   │   │
│  │  └───────────────────┘   │   │
│  │                         │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─ 昨天 ───────────────────┐   │
│  │  ┌───────────────────┐   │   │
│  │  │ 任务卡片 3       │   │   │
│  │  └───────────────────┘   │   │
│  └─────────────────────────┘   │
│                                 │
│                                 │
│          ┌─────┐                │
│          │  🔴 │  (录制按钮)     │
│          └─────┘                │
└─────────────────────────────────┘
```

#### 任务卡片设计
```
┌─────────────────────────────────────┐
│ Q1预算撕逼会              🟡 分析中  │
│                                     │
│ 10:30 - 11:15  (45分钟)             │
│                                     │
│ #PUA预警  #急躁  #画饼              │
│                                     │
│ 情绪分数: 60分                      │
└─────────────────────────────────────┘
```

**颜色方案**:
- 背景: 白色或浅灰色
- 标题: 深灰色 (#333333)
- 时间: 中灰色 (#666666)
- 标签: 不同颜色（红色=风险，黄色=警告，蓝色=普通）
- 状态指示器: 🔴红色=录制中，🟡黄色=分析中，🟢绿色=已完成

### 5.2 任务详情页 UI 设计

#### 布局结构
```
┌─────────────────────────────────┐
│  ← 返回          ⋮ 更多操作     │
├─────────────────────────────────┤
│  [战斗结算条]                    │
│  情绪: 60分  输出: 120句        │
│  叹气: 8次 (点击查看)            │
├─────────────────────────────────┤
│                                 │
│  ┌─ 段落 1: Q1预算讨论 ─────┐   │
│  │ 00:00 - 05:20           │   │
│  │                         │   │
│  │ 摘要: 讨论Q1季度预算... │   │
│  │                         │   │
│  │ 📌 策略: 老板正在施压，  │   │
│  │    建议回复：[查看话术]  │   │
│  │                         │   │
│  │ [展开查看对话 ▼]         │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─ 段落 2: 资源分配 ───────┐   │
│  │ ...                     │   │
│  └─────────────────────────┘   │
│                                 │
├─────────────────────────────────┤
│  [原文开关] [人物筛选] [🔥焚毁] │
└─────────────────────────────────┘
```

### 5.3 录制按钮设计

**正常状态**:
- 圆形红色按钮，直径 70pt
- 中央显示麦克风图标
- 位置: 底部中央，距离底部 30pt

**录制中状态**:
- 按钮变大（直径 80pt）
- 添加呼吸动画（透明度 0.7 ↔ 1.0，周期 1 秒）
- 显示录音时长（按钮上方或内部）
- 周围添加声波纹路动画（可选）

---

## 6. 数据模型设计

### 6.1 Swift 数据模型

#### Task (任务模型)
```swift
import Foundation

struct Task: Codable, Identifiable {
    let id: String                    // session_id
    let title: String                 // 任务标题
    let startTime: Date               // 开始时间
    let endTime: Date?                // 结束时间
    let duration: Int                 // 时长（秒）
    let tags: [String]                // 标签数组
    let status: TaskStatus            // 状态
    let emotionScore: Int?            // 情绪分数 (0-100)
    let speakerCount: Int?            // 说话人数
    let thumbnailURL: String?         // 缩略图 URL
    
    enum TaskStatus: String, Codable {
        case recording = "recording"    // 录制中
        case analyzing = "analyzing"    // 分析中
        case archived = "archived"      // 已归档
        case burned = "burned"          // 已焚毁
    }
}
```

#### Segment (对话段落模型)
```swift
struct Segment: Codable, Identifiable {
    let id: String                    // segment_id
    let title: String                 // 段落标题
    let startTime: Double             // 开始时间（秒）
    let endTime: Double               // 结束时间（秒）
    let summary: String                // 摘要
    let emotionTags: [String]         // 情绪标签
    let strategy: Strategy?           // 策略建议
    let risks: [String]               // 风险点
    let dialogues: [Dialogue]?       // 详细对话（展开时加载）
    
    struct Strategy: Codable {
        let type: String              // warning|suggestion|action
        let content: String            // 策略内容
        let tone: String              // diplomatic|firm|calm
    }
}
```

#### Dialogue (对话模型)
```swift
struct Dialogue: Codable, Identifiable {
    let id: String                    // dialogue_id
    let speakerId: String             // 说话人ID
    let speakerName: String?          // 说话人姓名（如果已注册）
    let content: String               // 说话内容
    let tone: String                  // 语气
    let timestamp: Double             // 时间戳（秒）
    let cpm: Int?                     // 语速（字符/分钟）
}
```

#### TaskDetail (任务详情模型)
```swift
struct TaskDetail: Codable {
    let task: Task
    let emotionStats: EmotionStats
    let segments: [Segment]
    let analysisId: String?
    
    struct EmotionStats: Codable {
        let score: Int                // 情绪分数
        let totalTurns: Int            // 总轮数
        let sighCount: Int            // 叹气次数
        let sighTimestamps: [Double]   // 叹气时间点
    }
}
```

### 6.2 API 响应模型

```swift
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: String?
}

struct TaskListResponse: Codable {
    let sessions: [Task]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let page: Int
        let pageSize: Int
        let total: Int
        let totalPages: Int
    }
}
```

---

## 7. 核心功能实现

### 7.1 录音功能实现

#### AudioRecorderService.swift
```swift
import AVFoundation
import Combine

class AudioRecorderService: NSObject, ObservableObject {
    // 录音器
    private var audioRecorder: AVAudioRecorder?
    
    // 录音状态
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    
    // 录音文件路径
    private var recordingURL: URL?
    
    // 定时器（用于更新录音时长）
    private var timer: Timer?
    
    // 单例
    static let shared = AudioRecorderService()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // 配置音频会话
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    // 开始录音
    func startRecording() -> Bool {
        // 请求麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                print("麦克风权限被拒绝")
                return
            }
            
            DispatchQueue.main.async {
                self?._startRecording()
            }
        }
        
        return true
    }
    
    private func _startRecording() {
        // 创建录音文件路径
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        recordingURL = audioFilename
        
        // 录音设置
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            // 创建录音器
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            // 更新状态
            isRecording = true
            recordingTime = 0
            
            // 启动定时器
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingTime += 0.1
            }
            
            print("开始录音: \(audioFilename)")
        } catch {
            print("录音启动失败: \(error)")
        }
    }
    
    // 停止录音
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        let url = recordingURL
        recordingURL = nil
        
        return url
    }
    
    // 取消录音
    func cancelRecording() {
        stopRecording()
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioRecorderService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("录音完成")
        } else {
            print("录音失败")
        }
    }
}
```

### 7.2 文件上传功能

#### FileUploadService.swift
```swift
import Alamofire
import Combine

class FileUploadService {
    static let shared = FileUploadService()
    private let baseURL = "http://your-api-server.com/api/v1"
    
    // 上传音频文件
    func uploadAudio(fileURL: URL, sessionId: String? = nil) -> AnyPublisher<UploadResponse, Error> {
        return Future { promise in
            // 创建 multipart form data
            AF.upload(
                multipartFormData: { multipartFormData in
                    // 添加文件
                    multipartFormData.append(
                        fileURL,
                        withName: "file",
                        fileName: fileURL.lastPathComponent,
                        mimeType: "audio/m4a"
                    )
                    
                    // 添加可选的 session_id
                    if let sessionId = sessionId {
                        multipartFormData.append(
                            sessionId.data(using: .utf8)!,
                            withName: "session_id"
                        )
                    }
                },
                to: "\(self.baseURL)/audio/upload",
                method: .post,
                headers: [
                    "Authorization": "Bearer \(self.getToken())"
                ]
            )
            .responseDecodable(of: APIResponse<UploadResponse>.self) { response in
                switch response.result {
                case .success(let apiResponse):
                    if apiResponse.code == 200, let data = apiResponse.data {
                        promise(.success(data))
                    } else {
                        promise(.failure(APIError.serverError(apiResponse.message)))
                    }
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func getToken() -> String {
        // 从 UserDefaults 或 Keychain 获取 JWT Token
        return UserDefaults.standard.string(forKey: "auth_token") ?? ""
    }
}

struct UploadResponse: Codable {
    let sessionId: String
    let audioId: String
    let status: String
    let estimatedDuration: Int?
}

enum APIError: Error {
    case serverError(String)
    case networkError(Error)
    case unauthorized
}
```

### 7.3 ViewModel 实现

#### TaskListViewModel.swift
```swift
import Foundation
import Combine

class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    // 加载任务列表
    func loadTasks(date: Date? = nil) {
        isLoading = true
        errorMessage = nil
        
        apiService.getTaskList(date: date)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.tasks = response.sessions
                }
            )
            .store(in: &cancellables)
    }
    
    // 刷新任务列表
    func refreshTasks() {
        loadTasks()
    }
}
```

#### RecordingViewModel.swift
```swift
import Foundation
import Combine

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    
    private let audioRecorder = AudioRecorderService.shared
    private let uploadService = FileUploadService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 开始录音
    func startRecording() {
        audioRecorder.startRecording()
        isRecording = true
        
        // 监听录音时长
        audioRecorder.$recordingTime
            .assign(to: &$recordingTime)
    }
    
    // 停止录音并上传
    func stopRecordingAndUpload() {
        guard let audioURL = audioRecorder.stopRecording() else {
            return
        }
        
        isRecording = false
        isUploading = true
        
        // 上传文件
        uploadService.uploadAudio(fileURL: audioURL)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isUploading = false
                    if case .failure(let error) = completion {
                        print("上传失败: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    print("上传成功: \(response.sessionId)")
                    // 可以发送通知，让 TaskListViewModel 刷新列表
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TaskUploaded"),
                        object: nil
                    )
                }
            )
            .store(in: &cancellables)
    }
    
    // 取消录音
    func cancelRecording() {
        audioRecorder.cancelRecording()
        isRecording = false
    }
}
```

---

## 8. API 接口设计

### 8.1 获取任务列表
**GET** `/api/v1/tasks/sessions`

**请求参数**:
- `date`: String (可选) - 日期，格式 `YYYY-MM-DD`
- `status`: String (可选) - 状态筛选
- `page`: Int (可选) - 页码
- `page_size`: Int (可选) - 每页数量

**响应示例**:
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
        "status": "analyzing",
        "emotion_score": null,
        "speaker_count": null
      }
    ],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 100
    }
  }
}
```

### 8.2 获取任务详情
**GET** `/api/v1/tasks/sessions/{session_id}`

**响应示例**: 见 API_DESIGN.md

### 8.3 上传音频文件
**POST** `/api/v1/audio/upload`

**请求**: multipart/form-data
- `file`: File (音频文件)
- `session_id`: String (可选)

**响应示例**: 见 API_DESIGN.md

---

## 9. 开发步骤详解

### 步骤 1: 创建基础项目结构（第 1 天）

1. **创建 Xcode 项目**
   - 按照 2.2 节的步骤创建项目

2. **添加 Swift Package 依赖**
   - 添加 Alamofire
   - 添加 Kingfisher（如果需要）

3. **创建文件夹结构**
   - 按照 4.2 节的文件夹结构创建目录

4. **配置 Info.plist**
   - 添加麦克风权限说明

### 步骤 2: 实现数据模型（第 2 天）

1. **创建 Model 文件**
   - `Task.swift`
   - `Segment.swift`
   - `Dialogue.swift`
   - `TaskDetail.swift`

2. **实现 Codable 协议**
   - 确保所有模型都遵循 `Codable` 协议
   - 处理日期格式转换（使用 `ISO8601DateFormatter`）

### 步骤 3: 实现网络服务层（第 3-4 天）

1. **创建 APIService.swift**
   ```swift
   class APIService {
       static let shared = APIService()
       private let baseURL = "http://your-api-server.com/api/v1"
       
       func getTaskList(date: Date? = nil) -> AnyPublisher<TaskListResponse, Error> {
           // 实现网络请求
       }
       
       func getTaskDetail(sessionId: String) -> AnyPublisher<TaskDetail, Error> {
           // 实现网络请求
       }
   }
   ```

2. **实现错误处理**
   - 定义 `APIError` 枚举
   - 处理网络错误、解析错误等

### 步骤 4: 实现录音功能（第 5 天）

1. **创建 AudioRecorderService.swift**
   - 按照 7.1 节的代码实现

2. **测试录音功能**
   - 在模拟器或真机上测试录音
   - 验证文件是否正确保存

### 步骤 5: 实现任务列表页（第 6-7 天）

1. **创建 TaskListView.swift**
   ```swift
   struct TaskListView: View {
       @StateObject private var viewModel = TaskListViewModel()
       
       var body: some View {
           NavigationView {
               List {
                   // 任务列表
               }
               .navigationTitle("任务 (副本)")
           }
       }
   }
   ```

2. **创建 TaskCardView.swift**
   - 实现任务卡片 UI
   - 添加点击事件，跳转到详情页

3. **实现按天分组**
   - 使用 `Dictionary` 按日期分组任务
   - 使用 `Section` 显示分组

### 步骤 6: 实现录制按钮（第 8 天）

1. **创建 RecordingButtonView.swift**
   - 实现悬浮按钮 UI
   - 添加呼吸动画

2. **集成 RecordingViewModel**
   - 连接录音服务和上传服务

### 步骤 7: 实现任务详情页（第 9-11 天）

1. **创建 TaskDetailView.swift**
   - 实现顶部战斗结算条
   - 实现分段式对话流
   - 实现底部交互栏

2. **创建 SegmentBlockView.swift**
   - 实现段落卡片 UI
   - 实现展开/收起功能

3. **实现人物筛选功能**
   - 创建说话人头像列表
   - 实现筛选逻辑

### 步骤 8: 实现焚毁功能（第 12 天）

1. **添加 Lottie 动画库**
2. **实现焚毁 API 调用**
3. **添加火焰动画效果**

### 步骤 9: 测试和优化（第 13-14 天）

1. **功能测试**
   - 测试所有功能点
   - 修复 bug

2. **性能优化**
   - 优化列表滚动性能
   - 优化图片加载

3. **UI 优化**
   - 调整颜色、字体、间距
   - 添加加载状态、错误提示

---

## 10. 常见问题解答

### Q1: 如何请求麦克风权限？
**A**: iOS 会在首次调用 `AVAudioRecorder` 时自动弹出权限请求。如果用户拒绝，需要在系统设置中手动开启。

### Q2: 录音文件保存在哪里？
**A**: 保存在 App 的 `Documents` 目录。上传成功后可以删除本地文件以节省空间。

### Q3: 如何处理网络错误？
**A**: 使用 `Alamofire` 的错误处理机制，在 ViewModel 中捕获错误并显示给用户。

### Q4: 如何实现下拉刷新？
**A**: 使用 SwiftUI 的 `.refreshable` 修饰符：
```swift
List {
    // 内容
}
.refreshable {
    viewModel.refreshTasks()
}
```

### Q5: 如何实现无限滚动？
**A**: 监听列表滚动到底部，加载下一页数据：
```swift
.onAppear {
    if task.id == tasks.last?.id {
        viewModel.loadMoreTasks()
    }
}
```

### Q6: 录音时如何显示在锁屏？
**A**: 使用 iOS 16+ 的 Live Activities 功能，需要配置 `ActivityKit`。

---

## 11. 下一步计划

完成"任务"模块后，可以继续开发：
1. **状态模块** - 老黄牛 Avatar 和压力桶
2. **档案模块** - 说话人建档和管理
3. **优化** - 性能优化、动画效果、用户体验

---

**文档版本**: v1.0  
**最后更新**: 2026-01-03  
**适用平台**: iOS 16.0+


