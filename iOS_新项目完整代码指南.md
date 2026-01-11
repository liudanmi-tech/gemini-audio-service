# WorkSurvivalGuideApp 新项目完整代码指南

## 📋 项目信息

- **项目名称**: WorkSurvivalGuide
- **项目路径**: `Models.swift/WorkSurvivalGuide/WorkSurvivalGuide/`
- **架构**: MVVM (Model-View-ViewModel)
- **UI 框架**: SwiftUI

---

## 🗂️ 第一步：创建文件夹结构

在 Xcode 项目导航器中，右键点击 `WorkSurvivalGuide` 文件夹（蓝色图标），创建以下文件夹结构：

```
WorkSurvivalGuide/
├── WorkSurvivalGuideApp.swift (已存在)
├── ContentView.swift (已存在，需要修改)
│
├── Models/                    ← 新建文件夹
│   └── Task.swift
│
├── Services/                  ← 新建文件夹
│   ├── NetworkManager.swift
│   └── AudioRecorderService.swift
│
├── ViewModels/                ← 新建文件夹
│   ├── TaskListViewModel.swift
│   └── RecordingViewModel.swift
│
└── Views/                     ← 新建文件夹
    ├── TaskListView.swift
    ├── TaskCardView.swift
    ├── RecordingButtonView.swift
    └── TaskDetailView.swift
```

### 创建文件夹的方法：

1. **在项目导航器中，右键点击 `WorkSurvivalGuide` 文件夹（蓝色图标）**
2. **选择 `New Group`**
3. **输入文件夹名称**（如 `Models`）
4. **重复上述步骤，创建其他文件夹**

---

## 📝 第二步：创建数据模型

### 文件 1: Models/Task.swift

**创建步骤**：
1. 右键点击 `Models` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`Task.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  Task.swift
//  WorkSurvivalGuide
//
//  任务数据模型
//

import Foundation

// 任务状态枚举
enum TaskStatus: String, Codable {
    case recording = "recording"    // 录制中
    case analyzing = "analyzing"    // 分析中
    case archived = "archived"       // 已归档
    case burned = "burned"          // 已焚毁
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

// MARK: - API 响应模型

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

## 🌐 第三步：创建网络服务

### 文件 2: Services/NetworkManager.swift

**创建步骤**：
1. 右键点击 `Services` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`NetworkManager.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  NetworkManager.swift
//  WorkSurvivalGuide
//
//  网络请求管理器
//

import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()
    
    // ⚠️ 重要：修改为你的后端 API 地址
    private let baseURL = "http://localhost:8001/api/v1"
    
    private init() {}
    
    // 获取认证 Token（暂时返回空字符串，后续实现登录后添加）
    private func getAuthToken() -> String {
        return UserDefaults.standard.string(forKey: "auth_token") ?? ""
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
        
        let response = try await AF.request(
            "\(baseURL)/tasks/sessions",
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ]
        )
        .serializingDecodable(APIResponse<TaskListResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "NetworkError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        return data
    }
    
    // 上传音频文件
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        let response = try await AF.upload(
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
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "NetworkError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        return data
    }
}
```

### 文件 3: Services/AudioRecorderService.swift

**创建步骤**：
1. 右键点击 `Services` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`AudioRecorderService.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  AudioRecorderService.swift
//  WorkSurvivalGuide
//
//  录音服务
//

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

## 🧠 第四步：创建 ViewModel

### 文件 4: ViewModels/TaskListViewModel.swift

**创建步骤**：
1. 右键点击 `ViewModels` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`TaskListViewModel.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  TaskListViewModel.swift
//  WorkSurvivalGuide
//
//  任务列表 ViewModel
//

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
                    print("加载任务失败: \(error)")
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

### 文件 5: ViewModels/RecordingViewModel.swift

**创建步骤**：
1. 右键点击 `ViewModels` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`RecordingViewModel.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  RecordingViewModel.swift
//  WorkSurvivalGuide
//
//  录音 ViewModel
//

import Foundation
import Combine

class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    
    private let audioRecorder = AudioRecorderService.shared
    private let networkManager = NetworkManager.shared
    private var timer: Timer?
    
    // 开始录音
    func startRecording() {
        audioRecorder.startRecording()
        isRecording = true
        
        // 监听录音时长
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else {
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
        timer?.invalidate()
        timer = nil
        isUploading = true
        
        Task {
            do {
                let response = try await networkManager.uploadAudio(fileURL: audioURL)
                await MainActor.run {
                    self.isUploading = false
                    print("上传成功: \(response.sessionId)")
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

## 🎨 第五步：创建视图组件

### 文件 6: Views/TaskCardView.swift

**创建步骤**：
1. 右键点击 `Views` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`TaskCardView.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  TaskCardView.swift
//  WorkSurvivalGuide
//
//  任务卡片组件
//

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

### 文件 7: Views/RecordingButtonView.swift

**创建步骤**：
1. 右键点击 `Views` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`RecordingButtonView.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  RecordingButtonView.swift
//  WorkSurvivalGuide
//
//  录制按钮组件
//

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
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)
    }
}
```

### 文件 8: Views/TaskListView.swift

**创建步骤**：
1. 右键点击 `Views` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`TaskListView.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  TaskListView.swift
//  WorkSurvivalGuide
//
//  任务列表主视图
//

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

### 文件 9: Views/TaskDetailView.swift

**创建步骤**：
1. 右键点击 `Views` 文件夹 → `New File...`
2. 选择 `Swift File`
3. 文件名输入：`TaskDetailView.swift`
4. 点击 `Create`

**代码内容**：

```swift
//
//  TaskDetailView.swift
//  WorkSurvivalGuide
//
//  任务详情视图（简化版）
//

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

## 🔧 第六步：修改 ContentView.swift

**打开现有的 `ContentView.swift` 文件，替换为以下代码**：

```swift
//
//  ContentView.swift
//  WorkSurvivalGuide
//
//  主 TabView
//

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

#Preview {
    ContentView()
}
```

---

## ⚙️ 第七步：项目配置

### 1. 添加 Alamofire 依赖

1. **在项目导航器中，点击项目名称（蓝色图标，最顶部）**
2. **在中间面板，点击 `Package Dependencies` 标签**
3. **点击左下角的 `+` 按钮**
4. **在搜索框中输入**：`https://github.com/Alamofire/Alamofire.git`
5. **点击 `Add Package`**
6. **选择版本**：`Up to Next Major Version`，输入 `5.8.0`
7. **点击 `Add Package`**
8. **在下一个界面，确保 `Alamofire` 被勾选**
9. **点击 `Add Package`**
10. **等待下载完成**

### 2. 设置 Deployment Target

1. **点击项目名称旁边的 `>` 展开**
2. **在 `TARGETS` 下，点击 `WorkSurvivalGuide`**
3. **在中间面板，点击 `General` 标签**
4. **找到 `Deployment Info` 部分**
5. **修改 `iOS` 版本为 `16.0`**

### 3. 添加麦克风权限

1. **在项目导航器中，找到 `Info.plist` 文件**
2. **双击打开**
3. **右键点击空白处** → `Add Row`
4. **在 Key 列输入**：`Privacy - Microphone Usage Description`
5. **在 Value 列输入**：`需要访问麦克风以录制会议音频`

### 4. 配置 API 地址

1. **打开 `Services/NetworkManager.swift`**
2. **找到 `baseURL` 这一行**（大约第 17 行）
3. **根据你的情况修改**：
   - 本地测试：`http://localhost:8001/api/v1`
   - 服务器：`http://your-server-ip:8001/api/v1`

---

## ✅ 完成检查清单

完成所有步骤后，检查：

- [ ] 所有文件夹都已创建（Models、Services、ViewModels、Views）
- [ ] 所有 9 个代码文件都已创建
- [ ] ContentView.swift 已更新
- [ ] Alamofire 已安装
- [ ] Deployment Target 设置为 iOS 16.0
- [ ] 麦克风权限已添加
- [ ] API 地址已配置
- [ ] 项目可以编译通过

---

## 🚀 运行项目

1. **选择模拟器**（顶部工具栏）
2. **点击 ▶ 按钮运行**
3. **测试功能**：
   - 点击录制按钮测试录音
   - 查看任务列表

---

## 🆘 遇到问题？

如果编译报错，检查：
1. 所有文件是否都已添加到项目（蓝色图标）
2. Alamofire 是否正确安装
3. 所有 import 语句是否正确

如果遇到问题，告诉我具体的错误信息，我会帮你解决！


