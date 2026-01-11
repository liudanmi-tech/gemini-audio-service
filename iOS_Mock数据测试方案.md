# iOS 客户端 Mock 数据测试方案

## 🎯 开发策略

**渐进式开发**：
1. ✅ 使用 Mock 数据测试 UI 和交互逻辑
2. ✅ 验证所有功能正常
3. ✅ 逐步切换到真实 API
4. ✅ 识别和修复问题

---

## 📋 技术方案

### 方案概述

创建一个 **Mock 服务层**，可以无缝切换 Mock 数据和真实 API：

```
iOS 客户端
    ↓
NetworkManager (统一接口)
    ├─→ MockNetworkService (Mock 数据)
    └─→ RealNetworkService (真实 API)
```

---

## 🔧 实现步骤

### 步骤 1: 创建 Mock 数据服务

#### 文件：Services/MockNetworkService.swift

```swift
//
//  MockNetworkService.swift
//  WorkSurvivalGuide
//
//  Mock 数据服务（用于测试）
//

import Foundation
import Combine

class MockNetworkService {
    static let shared = MockNetworkService()
    
    private init() {}
    
    // 模拟网络延迟
    private func delay(seconds: Double = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    // Mock 获取任务列表
    func getTaskList(
        date: Date? = nil,
        status: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> TaskListResponse {
        // 模拟网络延迟
        await delay(seconds: 0.5)
        
        // 生成 Mock 数据
        let mockTasks = generateMockTasks()
        
        return TaskListResponse(
            sessions: mockTasks,
            pagination: TaskListResponse.Pagination(
                page: page,
                pageSize: pageSize,
                total: mockTasks.count,
                totalPages: 1
            )
        )
    }
    
    // Mock 上传音频文件
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        // 模拟上传延迟
        await delay(seconds: 2.0)
        
        // 生成 Mock 响应
        return UploadResponse(
            sessionId: UUID().uuidString,
            audioId: UUID().uuidString,
            status: "analyzing",
            estimatedDuration: 300
        )
    }
    
    // 生成 Mock 任务数据
    private func generateMockTasks() -> [Task] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            // 今天的任务
            createMockTask(
                id: "task-1",
                title: "Q1预算撕逼会",
                startTime: calendar.date(byAdding: .hour, value: -2, to: now)!,
                endTime: calendar.date(byAdding: .hour, value: -1, to: now)!,
                duration: 3600,
                tags: ["#PUA预警", "#急躁", "#画饼"],
                status: .archived,
                emotionScore: 60,
                speakerCount: 3
            ),
            createMockTask(
                id: "task-2",
                title: "晨间站会",
                startTime: calendar.date(byAdding: .hour, value: -5, to: now)!,
                endTime: calendar.date(byAdding: .hour, value: -4, to: now)!,
                duration: 3600,
                tags: ["#正常", "#进度汇报"],
                status: .archived,
                emotionScore: 75,
                speakerCount: 5
            ),
            createMockTask(
                id: "task-3",
                title: "产品需求评审",
                startTime: calendar.date(byAdding: .hour, value: -8, to: now)!,
                endTime: calendar.date(byAdding: .hour, value: -7, to: now)!,
                duration: 3600,
                tags: ["#争论", "#需求变更"],
                status: .analyzing,
                emotionScore: nil,
                speakerCount: nil
            ),
            // 昨天的任务
            createMockTask(
                id: "task-4",
                title: "周会",
                startTime: calendar.date(byAdding: .day, value: -1, to: now)!,
                endTime: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(3600),
                duration: 3600,
                tags: ["#周报", "#计划"],
                status: .archived,
                emotionScore: 80,
                speakerCount: 8
            ),
        ]
    }
    
    // 创建 Mock 任务
    private func createMockTask(
        id: String,
        title: String,
        startTime: Date,
        endTime: Date,
        duration: Int,
        tags: [String],
        status: TaskStatus,
        emotionScore: Int?,
        speakerCount: Int?
    ) -> Task {
        // 注意：这里需要手动构造 Task，因为 Task 有自定义的 init(from decoder)
        // 我们需要创建一个简单的初始化方法，或者使用 JSON 解码
        
        // 使用 JSON 编码/解码来创建 Task
        let jsonString = """
        {
            "session_id": "\(id)",
            "title": "\(title)",
            "start_time": "\(ISO8601DateFormatter().string(from: startTime))",
            "end_time": "\(ISO8601DateFormatter().string(from: endTime))",
            "duration": \(duration),
            "tags": \(tags.map { "\"\($0)\"" }.joined(separator: ", ")),
            "status": "\(status.rawValue)",
            "emotion_score": \(emotionScore != nil ? "\(emotionScore!)" : "null"),
            "speaker_count": \(speakerCount != nil ? "\(speakerCount!)" : "null")
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        return try! JSONDecoder().decode(Task.self, from: data)
    }
}
```

---

### 步骤 2: 创建环境配置

#### 文件：Shared/AppConfig.swift

```swift
//
//  AppConfig.swift
//  WorkSurvivalGuide
//
//  应用配置（环境切换）
//

import Foundation

enum Environment {
    case development  // 开发环境（使用 Mock 数据）
    case production   // 生产环境（使用真实 API）
}

class AppConfig {
    static let shared = AppConfig()
    
    // 当前环境（可以通过 UserDefaults 或编译配置切换）
    var currentEnvironment: Environment {
        // 方法 1: 通过 UserDefaults 切换（运行时切换）
        if let useMock = UserDefaults.standard.object(forKey: "use_mock_data") as? Bool {
            return useMock ? .development : .production
        }
        
        // 方法 2: 通过编译配置切换（编译时切换）
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    // 是否使用 Mock 数据
    var useMockData: Bool {
        return currentEnvironment == .development
    }
    
    private init() {}
    
    // 切换环境（用于测试）
    func setUseMockData(_ useMock: Bool) {
        UserDefaults.standard.set(useMock, forKey: "use_mock_data")
    }
}
```

---

### 步骤 3: 修改 NetworkManager 支持 Mock

#### 修改：Services/NetworkManager.swift

```swift
//
//  NetworkManager.swift
//  WorkSurvivalGuide
//
//  网络请求管理器（支持 Mock 和真实 API）
//

import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()
    
    private let config = AppConfig.shared
    private let mockService = MockNetworkService.shared
    
    // ⚠️ 重要：修改为你的后端 API 地址
    private let baseURL = "http://47.79.254.213/api/v1"
    
    private init() {}
    
    // 获取认证 Token
    private func getAuthToken() -> String {
        return UserDefaults.standard.string(forKey: "auth_token") ?? ""
    }
    
    // 获取任务列表（支持 Mock 和真实 API）
    func getTaskList(
        date: Date? = nil,
        status: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> TaskListResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            return try await mockService.getTaskList(
                date: date,
                status: status,
                page: page,
                pageSize: pageSize
            )
        }
        
        // 使用真实 API
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
    
    // 上传音频文件（支持 Mock 和真实 API）
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            return try await mockService.uploadAudio(
                fileURL: fileURL,
                sessionId: sessionId
            )
        }
        
        // 使用真实 API
        let response = try await AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(
                    fileURL,
                    withName: "file",
                    fileName: fileURL.lastPathComponent,
                    mimeType: "audio/m4a"
                )
                
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

---

### 步骤 4: 添加环境切换功能（可选）

#### 在设置页面添加切换开关

```swift
//
//  SettingsView.swift (可选，用于测试时切换)
//  WorkSurvivalGuide
//

import SwiftUI

struct SettingsView: View {
    @State private var useMockData = AppConfig.shared.useMockData
    
    var body: some View {
        Form {
            Section(header: Text("开发设置")) {
                Toggle("使用 Mock 数据", isOn: $useMockData)
                    .onChange(of: useMockData) { newValue in
                        AppConfig.shared.setUseMockData(newValue)
                    }
            }
        }
        .navigationTitle("设置")
    }
}
```

---

## 📝 简化版 Mock 数据（如果上面的太复杂）

### 简化版：直接在 NetworkManager 中添加 Mock 方法

如果不想创建太多文件，可以这样：

```swift
class NetworkManager {
    // 添加一个开关
    static var useMockData = true  // 改为 false 使用真实 API
    
    func getTaskList(...) async throws -> TaskListResponse {
        if Self.useMockData {
            // 返回 Mock 数据
            return createMockTaskList()
        }
        // 真实 API 调用
        ...
    }
    
    private func createMockTaskList() -> TaskListResponse {
        // 简单的 Mock 数据
        ...
    }
}
```

---

## 🧪 测试流程

### 阶段 1: Mock 数据测试

1. **设置 `AppConfig.shared.setUseMockData(true)`**
2. **测试所有 UI 功能**：
   - 任务列表显示
   - 任务卡片样式
   - 下拉刷新
   - 录制按钮
   - 任务详情页
3. **验证交互逻辑**：
   - 点击任务卡片跳转
   - 录制按钮状态变化
   - 空状态显示

### 阶段 2: 逐步切换到真实 API

1. **先测试健康检查接口**：
   ```swift
   // 在 NetworkManager 中添加
   func testConnection() async throws {
       let response = try await AF.request("\(baseURL)/health")
       print("连接成功: \(response)")
   }
   ```

2. **测试获取任务列表**：
   - 设置 `useMockData = false`
   - 测试列表加载

3. **测试上传音频**：
   - 测试录音功能
   - 测试文件上传
   - 测试分析结果

---

## ✅ 推荐方案

### 方案 A: 完整方案（推荐）

- 创建 `MockNetworkService.swift`
- 创建 `AppConfig.swift`
- 修改 `NetworkManager.swift` 支持切换
- **优点**：代码清晰，易于维护
- **缺点**：需要创建更多文件

### 方案 B: 简化方案

- 直接在 `NetworkManager.swift` 中添加 Mock 方法
- 使用静态变量控制开关
- **优点**：简单快速
- **缺点**：代码稍乱

---

## 🎯 我的推荐

**推荐使用方案 A（完整方案）**，因为：
1. 代码结构更清晰
2. 易于维护和扩展
3. 可以轻松切换环境
4. Mock 数据可以更丰富

---

## 📋 实施步骤

1. **创建 `AppConfig.swift`**（环境配置）
2. **创建 `MockNetworkService.swift`**（Mock 数据服务）
3. **修改 `NetworkManager.swift`**（支持切换）
4. **测试 Mock 数据**（验证 UI 和交互）
5. **逐步切换到真实 API**（一点一点测试）

需要我帮你创建这些文件吗？还是你想先看看代码？

