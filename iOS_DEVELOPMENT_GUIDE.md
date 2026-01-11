# iOS 客户端开发指南 - 从零开始

## 📚 目录
1. [准备工作](#准备工作)
2. [创建项目](#创建项目)
3. [项目结构搭建](#项目结构搭建)
4. [实现数据模型](#实现数据模型)
5. [实现网络服务](#实现网络服务)
6. [实现录音功能](#实现录音功能)
7. [实现任务列表页](#实现任务列表页)
8. [实现任务详情页](#实现任务详情页)
9. [测试和调试](#测试和调试)

---

## 准备工作

### 步骤 1: 安装 Xcode

1. **打开 App Store**
   - 在 Mac 上打开 App Store 应用

2. **搜索 Xcode**
   - 在搜索框输入 "Xcode"
   - 点击"获取"或"安装"按钮

3. **等待安装完成**
   - Xcode 很大（约 10GB+），需要较长时间
   - 安装完成后，打开 Xcode

4. **接受许可协议**
   - 首次打开 Xcode 会要求接受许可协议
   - 点击"Agree"（同意）

5. **安装额外组件**
   - Xcode 会自动下载并安装必要的组件
   - 等待完成（可能需要几分钟）

### 步骤 2: 检查系统要求

- **macOS**: 13.0 (Ventura) 或更高版本
- **Xcode**: 15.0 或更高版本
- **iOS 模拟器**: iOS 16.0 或更高版本

---

## 创建项目

### 步骤 1: 创建新项目

1. **打开 Xcode**
   - 点击桌面上的 Xcode 图标

2. **选择创建新项目**
   - 在欢迎界面，点击 "Create a new Xcode project"
   - 或者选择 `File` → `New` → `Project...`

3. **选择项目模板**
   - 在左侧选择 **iOS**
   - 在右侧选择 **App**
   - 点击 **Next**

4. **填写项目信息**
   ```
   Product Name: WorkSurvivalGuide
   Team: 选择你的 Apple ID（如果没有，点击 "Add Account..."）
   Organization Identifier: com.yourname (例如: com.liudan)
   Interface: SwiftUI
   Language: Swift
   Storage: None (暂时不选 Core Data)
   Include Tests: 可以取消勾选（暂时不需要）
   ```
   - 点击 **Next**

5. **选择保存位置**
   - 选择一个文件夹保存项目（例如：`~/Desktop/AI军师/`）
   - 点击 **Create**

6. **等待项目创建完成**
   - Xcode 会自动打开项目
   - 你会看到项目导航器（左侧）和代码编辑器（中间）

### 步骤 2: 配置项目设置

1. **设置部署目标**
   - 在项目导航器中，点击最顶部的项目名称（蓝色图标）
   - 在中间面板，选择 **WorkSurvivalGuide** target
   - 在 **General** 标签页，找到 **Deployment Info**
   - 将 **iOS** 设置为 **16.0**

2. **添加麦克风权限**
   - 在项目导航器中，找到 `Info.plist` 文件
   - 点击打开
   - 右键点击空白处，选择 **Add Row**
   - 在 **Key** 列输入：`Privacy - Microphone Usage Description`
   - 在 **Value** 列输入：`需要访问麦克风以录制会议音频`

3. **保存项目**
   - 按 `Cmd + S` 保存

---

## 项目结构搭建

### 步骤 1: 创建文件夹结构

在项目导航器中，右键点击 `WorkSurvivalGuide` 文件夹（蓝色图标），选择 **New Group**，创建以下文件夹结构：

```
WorkSurvivalGuide/
├── App/
│   └── WorkSurvivalGuideApp.swift (已存在)
├── TaskModule/
│   ├── Views/
│   ├── ViewModels/
│   ├── Models/
│   └── Services/
└── Shared/
    ├── Models/
    └── Utilities/
```

**创建方法**：
1. 右键点击 `WorkSurvivalGuide` → `New Group` → 输入 `TaskModule`
2. 右键点击 `TaskModule` → `New Group` → 输入 `Views`
3. 重复上述步骤创建其他文件夹

### 步骤 2: 添加第三方库（Alamofire）

1. **打开 Package Dependencies**
   - 在项目导航器中，点击项目名称（蓝色图标）
   - 选择 **WorkSurvivalGuide** target
   - 点击顶部的 **Package Dependencies** 标签

2. **添加 Alamofire**
   - 点击左下角的 **+** 按钮
   - 在搜索框输入：`https://github.com/Alamofire/Alamofire.git`
   - 点击 **Add Package**
   - 选择版本：**Up to Next Major Version**，输入 `5.8.0`
   - 点击 **Add Package**
   - 在下一个界面，确保 **Alamofire** 被勾选
   - 点击 **Add Package**

3. **等待下载完成**
   - Xcode 会自动下载并集成 Alamofire

---

## 实现数据模型

### 步骤 1: 创建 Task 模型

1. **创建文件**
   - 右键点击 `TaskModule/Models` 文件夹
   - 选择 **New File...**
   - 选择 **Swift File**
   - 文件名输入：`Task.swift`
   - 点击 **Create**

2. **编写代码**
   复制以下代码到 `Task.swift`：

```swift
import Foundation

// 任务状态枚举
enum TaskStatus: String, Codable {
    case recording = "recording"    // 录制中
    case analyzing = "analyzing"    // 分析中
    case archived = "archived"       // 已归档
    case burned = "burned"           // 已焚毁
}

// 任务数据模型
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
    
    // 自定义 CodingKeys 用于处理 API 返回的字段名
    enum CodingKeys: String, CodingKey {
        case id = "session_id"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case tags
        case status
        case emotionScore = "emotion_score"
        case speakerCount = "speaker_count"
    }
    
    // 自定义日期解码器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        
        // 解析日期字符串
        let startTimeString = try container.decode(String.self, forKey: .startTime)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        startTime = dateFormatter.date(from: startTimeString) ?? Date()
        
        // 解析可选的结束时间
        if let endTimeString = try? container.decode(String.self, forKey: .endTime) {
            endTime = dateFormatter.date(from: endTimeString)
        } else {
            endTime = nil
        }
        
        duration = try container.decode(Int.self, forKey: .duration)
        tags = try container.decode([String].self, forKey: .tags)
        status = try container.decode(TaskStatus.self, forKey: .status)
        emotionScore = try? container.decode(Int.self, forKey: .emotionScore)
        speakerCount = try? container.decode(Int.self, forKey: .speakerCount)
    }
    
    // 格式化时长显示
    var durationString: String {
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(seconds)秒"
        }
    }
    
    // 格式化时间范围显示
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: startTime)
        if let endTime = endTime {
            let end = formatter.string(from: endTime)
            return "\(start) - \(end)"
        }
        return start
    }
}
```

### 步骤 2: 创建 API 响应模型

1. **创建文件** `Shared/Models/APIResponse.swift`

```swift
import Foundation

// API 通用响应结构
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: String?
}

// 任务列表响应
struct TaskListResponse: Codable {
    let sessions: [Task]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let page: Int
        let pageSize: Int
        let total: Int
        let totalPages: Int
        
        enum CodingKeys: String, CodingKey {
            case page
            case pageSize = "page_size"
            case total
            case totalPages = "total_pages"
        }
    }
}

// 上传响应
struct UploadResponse: Codable {
    let sessionId: String
    let audioId: String
    let status: String
    let estimatedDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case audioId = "audio_id"
        case status
        case estimatedDuration = "estimated_duration"
    }
}
```

---

## 实现网络服务

### 步骤 1: 创建网络管理器

1. **创建文件** `Shared/Utilities/NetworkManager.swift`

```swift
import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()
    
    // 替换为你的后端 API 地址
    private let baseURL = "http://localhost:8001/api/v1"
    
    private init() {}
    
    // 获取认证 Token（暂时返回空字符串，后续实现登录后添加）
    private func getAuthToken() -> String {
        return UserDefaults.standard.string(forKey: "auth_token") ?? ""
    }
    
    // 通用请求方法
    private func request<T: Codable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        headers: HTTPHeaders? = nil
    ) -> DataRequest {
        var requestHeaders: HTTPHeaders = [
            "Content-Type": "application/json"
        ]
        
        // 添加认证 Token
        let token = getAuthToken()
        if !token.isEmpty {
            requestHeaders["Authorization"] = "Bearer \(token)"
        }
        
        // 合并自定义 headers
        if let customHeaders = headers {
            customHeaders.forEach { requestHeaders[$0.name] = $0.value }
        }
        
        return AF.request(
            "\(baseURL)\(endpoint)",
            method: method,
            parameters: parameters,
            headers: requestHeaders
        )
    }
    
    // 获取任务列表
    func getTaskList(
        date: Date? = nil,
        status: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> TaskListResponse {
        var parameters: [String: Any] = [
            "page": page,
            "page_size": pageSize
        ]
        
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parameters["date"] = formatter.string(from: date)
        }
        
        if let status = status {
            parameters["status"] = status
        }
        
        return try await request("/tasks/sessions", parameters: parameters)
            .serializingDecodable(APIResponse<TaskListResponse>.self)
            .value
            .data!
    }
    
    // 上传音频文件
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        return try await AF.upload(
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
            to: "\(baseURL)/audio/upload",
            method: .post,
            headers: [
                "Authorization": "Bearer \(getAuthToken())"
            ]
        )
        .serializingDecodable(APIResponse<UploadResponse>.self)
        .value
        .data!
    }
}
```

---

## 实现录音功能

### 步骤 1: 创建录音服务

1. **创建文件** `TaskModule/Services/AudioRecorderService.swift`

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
    func startRecording() {
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
    
    // 格式化录音时长
    var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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

---

## 实现任务列表页

### 步骤 1: 创建 ViewModel

1. **创建文件** `TaskModule/ViewModels/TaskListViewModel.swift`

```swift
import Foundation
import Combine

class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    
    // 加载任务列表
    func loadTasks(date: Date? = nil) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await networkManager.getTaskList(date: date)
                await MainActor.run {
                    self.tasks = response.sessions
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // 刷新任务列表
    func refreshTasks() {
        loadTasks()
    }
    
    // 按天分组任务
    var groupedTasks: [String: [Task]] {
        Dictionary(grouping: tasks) { task in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: task.startTime)
        }
    }
    
    // 获取分组标题
    func groupTitle(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: date)
        }
    }
}
```

### 步骤 2: 创建任务卡片视图

1. **创建文件** `TaskModule/Views/Components/TaskCardView.swift`

```swift
import SwiftUI

struct TaskCardView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和状态
            HStack {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 状态指示器
                StatusIndicator(status: task.status)
            }
            
            // 时间和时长
            HStack {
                Text(task.timeRangeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(task.durationString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 标签
            if !task.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(task.tags, id: \.self) { tag in
                            TagView(text: tag)
                        }
                    }
                }
            }
            
            // 情绪分数
            if let score = task.emotionScore {
                HStack {
                    Text("情绪分数:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(score)分")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(emotionColor(for: score))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // 根据情绪分数返回颜色
    private func emotionColor(for score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

// 状态指示器
struct StatusIndicator: View {
    let status: TaskStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .recording:
            return .red
        case .analyzing:
            return .orange
        case .archived:
            return .green
        case .burned:
            return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .recording:
            return "录制中"
        case .analyzing:
            return "分析中"
        case .archived:
            return "已归档"
        case .burned:
            return "已焚毁"
        }
    }
}

// 标签视图
struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tagColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var tagColor: Color {
        if text.contains("PUA") || text.contains("风险") {
            return .red
        } else if text.contains("急躁") || text.contains("焦虑") {
            return .orange
        } else {
            return .blue
        }
    }
}
```

### 步骤 3: 创建任务列表视图

1. **创建文件** `TaskModule/Views/TaskListView.swift`

```swift
import SwiftUI

struct TaskListView: View {
    @StateObject private var viewModel = TaskListViewModel()
    @StateObject private var recordingViewModel = RecordingViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // 任务列表
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView("加载中...")
                } else if viewModel.tasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("还没有任务")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击下方按钮开始录音")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 按天分组显示
                            ForEach(Array(viewModel.groupedTasks.keys.sorted(by: >)), id: \.self) { dateKey in
                                Section {
                                    ForEach(viewModel.groupedTasks[dateKey] ?? []) { task in
                                        NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                            TaskCardView(task: task)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                } header: {
                                    HStack {
                                        Text(viewModel.groupTitle(for: dateKey))
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(.horizontal)
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        viewModel.refreshTasks()
                    }
                }
                
                // 悬浮录制按钮
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        RecordingButtonView(viewModel: recordingViewModel)
                            .padding(.trailing, 20)
                            .padding(.bottom, 30)
                    }
                }
            }
            .navigationTitle("任务 (副本)")
            .onAppear {
                viewModel.loadTasks()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TaskUploaded"))) { _ in
                // 任务上传成功后刷新列表
                viewModel.refreshTasks()
            }
        }
    }
}
```

### 步骤 4: 创建录制按钮视图

1. **创建文件** `TaskModule/Views/Components/RecordingButtonView.swift`

```swift
import SwiftUI

struct RecordingButtonView: View {
    @ObservedObject var viewModel: RecordingViewModel
    
    var body: some View {
        Button(action: {
            if viewModel.isRecording {
                viewModel.stopRecordingAndUpload()
            } else {
                viewModel.startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.blue)
                    .frame(width: viewModel.isRecording ? 80 : 70, height: viewModel.isRecording ? 80 : 70)
                    .shadow(radius: 8)
                    .opacity(viewModel.isRecording ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)
                
                if viewModel.isRecording {
                    VStack {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text(viewModel.formattedTime)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(viewModel.isUploading)
    }
}
```

### 步骤 5: 创建录制 ViewModel

1. **创建文件** `TaskModule/ViewModels/RecordingViewModel.swift`

```swift
import Foundation
import Combine

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    
    private let audioRecorder = AudioRecorderService.shared
    private let networkManager = NetworkManager.shared
    
    // 开始录音
    func startRecording() {
        audioRecorder.startRecording()
        isRecording = true
        
        // 监听录音时长
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, self.isRecording else {
                timer.invalidate()
                return
            }
            self.recordingTime = self.audioRecorder.recordingTime
        }
    }
    
    // 停止录音并上传
    func stopRecordingAndUpload() {
        guard let audioURL = audioRecorder.stopRecording() else {
            return
        }
        
        isRecording = false
        isUploading = true
        
        Task {
            do {
                let response = try await networkManager.uploadAudio(fileURL: audioURL)
                await MainActor.run {
                    self.isUploading = false
                    // 发送通知，让 TaskListViewModel 刷新列表
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TaskUploaded"),
                        object: nil
                    )
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
                    print("上传失败: \(error)")
                }
            }
        }
    }
    
    // 格式化录音时长
    var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
```

---

## 实现任务详情页（简化版）

### 步骤 1: 创建任务详情视图

1. **创建文件** `TaskModule/Views/TaskDetailView.swift`

```swift
import SwiftUI

struct TaskDetailView: View {
    let taskId: String
    @State private var task: Task?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("加载中...")
                    .padding()
            } else if let task = task {
                VStack(alignment: .leading, spacing: 20) {
                    // 任务信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(task.timeRangeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let score = task.emotionScore {
                            Text("情绪分数: \(score)分")
                                .font(.headline)
                                .foregroundColor(emotionColor(for: score))
                        }
                    }
                    .padding()
                    
                    // 标签
                    if !task.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(task.tags, id: \.self) { tag in
                                    TagView(text: tag)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Text("详情功能开发中...")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTaskDetail()
        }
    }
    
    private func loadTaskDetail() {
        // TODO: 实现加载任务详情的逻辑
        isLoading = false
    }
    
    private func emotionColor(for score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}
```

---

## 更新主 App 文件

### 步骤 1: 修改 ContentView

1. **打开** `ContentView.swift`（应该已经存在）

2. **替换内容**：

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TaskListView()
                .tabItem {
                    Label("任务", systemImage: "list.bullet")
                }
            
            Text("状态")
                .tabItem {
                    Label("状态", systemImage: "person.fill")
                }
            
            Text("档案")
                .tabItem {
                    Label("档案", systemImage: "folder.fill")
                }
        }
    }
}
```

---

## 测试和调试

### 步骤 1: 运行项目

1. **选择模拟器**
   - 在 Xcode 顶部工具栏，点击设备选择器
   - 选择 **iPhone 15 Pro** 或任意 iOS 16+ 模拟器

2. **运行项目**
   - 点击左上角的 **▶** 按钮
   - 或按 `Cmd + R`

3. **等待编译和启动**
   - Xcode 会编译项目（第一次可能需要几分钟）
   - 模拟器会自动启动并运行 APP

### 步骤 2: 测试功能

1. **测试录音功能**
   - 点击底部的红色录制按钮
   - 应该会弹出麦克风权限请求
   - 点击"允许"
   - 按钮应该开始闪烁，显示录音时长
   - 再次点击停止录音

2. **测试任务列表**
   - 如果后端 API 已配置，应该能看到任务列表
   - 如果没有后端，会显示"还没有任务"

### 步骤 3: 常见问题

**问题 1: 编译错误**
- 检查 Alamofire 是否正确安装
- 检查所有文件是否都添加到项目中（在项目导航器中确认）

**问题 2: 运行时崩溃**
- 查看 Xcode 底部的控制台输出
- 检查错误信息

**问题 3: 麦克风权限被拒绝**
- 在模拟器中：`Settings` → `Privacy` → `Microphone` → 开启权限
- 在真机上：`Settings` → `WorkSurvivalGuide` → `Microphone` → 开启权限

---

## 下一步

完成基础功能后，可以继续实现：
1. 任务详情页的完整功能
2. 对话段落展示
3. 策略建议显示
4. 焚毁功能
5. 下拉刷新和无限滚动

---

**提示**: 如果遇到任何问题，请查看 Xcode 的控制台输出，那里会显示详细的错误信息。

