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
    @Published var uploadProgress: Double = 0  // 0~1，1.0 表示已发送完毕，等待服务器响应
    @Published var uploadPhaseDescription: String = "Uploading"  // "Uploading" | "Processing, please wait..."
    
    private let audioRecorder = AudioRecorderService.shared
    private let networkManager = NetworkManager.shared
    private var timer: Timer?
    private var currentRecordingTaskId: String? // 当前录音任务的 ID
    
    // 开始录音
    func startRecording() {
        print("🎤 [RecordingViewModel] ========== 开始录制 ==========")
        print("🎤 [RecordingViewModel] 调用 AudioRecorderService.startRecording()")
        audioRecorder.startRecording()
        isRecording = true
        recordingTime = 0
        print("🎤 [RecordingViewModel] ✅ 录制状态已设置为 true")
        
        // 立即创建本地录音卡片，状态为"正在转录语音..."
        let startTime = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeString = formatter.string(from: startTime)
        
        let taskId = UUID().uuidString
        currentRecordingTaskId = taskId // 保存当前录音任务 ID
        
        let newTask = TaskItem(
            id: taskId,
            title: "Recording \(timeString)",
            startTime: startTime,
            endTime: nil,
            duration: 0,
            tags: [],
            status: .recording, // 状态为"正在转录语音..."
            emotionScore: nil,
            speakerCount: nil
        )
        
        print("📝 [RecordingViewModel] 立即创建本地录音卡片:")
        print("   - ID: \(newTask.id)")
        print("   - 标题: \(newTask.title)")
        print("   - 状态: \(newTask.status)")
        
        // 通知 TaskListViewModel 添加新任务
        Task { @MainActor in
            print("📢 [RecordingViewModel] 发送 NewTaskCreated 通知（录音开始）")
            NotificationCenter.default.post(
                name: NSNotification.Name("NewTaskCreated"),
                object: newTask
            )
        }
        
        // 监听录音时长
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecording else {
                return
            }
            self.recordingTime = self.audioRecorder.recordingTime
        }
        print("🎤 [RecordingViewModel] ✅ 录音时长监听器已启动")
    }
    
    // 停止录音并上传
    func stopRecordingAndUpload() {
        print("🛑 [RecordingViewModel] ========== 停止录制并上传 ==========")
        print("🛑 [RecordingViewModel] 当前录制时长: \(recordingTime) 秒")
        print("🛑 [RecordingViewModel] 调用 AudioRecorderService.stopRecording()")
        
        guard let audioURL = audioRecorder.stopRecording() else {
            print("❌ [RecordingViewModel] 停止录制失败：audioURL 为 nil")
            return
        }
        
        print("✅ [RecordingViewModel] 录制停止成功")
        print("📁 [RecordingViewModel] 音频文件路径: \(audioURL.path)")
        let fileSizeBytes = getFileSize(url: audioURL)
        print("📁 [RecordingViewModel] 音频文件大小: \(fileSizeBytes) 字节")
        if fileSizeBytes > 20 * 1024 * 1024 {
            let mb = Double(fileSizeBytes) / (1024 * 1024)
            print("📎 [RecordingViewModel] 大文件（\(String(format: "%.1f", mb)) MB > 20 MB），服务端将自动分段分析")
        }
        
        let recordingDuration = Int(recordingTime)
        let startTime = Date().addingTimeInterval(-recordingTime)
        let endTime = Date()
        
        print("⏱️ [RecordingViewModel] 录制时长: \(recordingDuration) 秒")
        print("⏱️ [RecordingViewModel] 开始时间: \(startTime)")
        print("⏱️ [RecordingViewModel] 结束时间: \(endTime)")
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        isUploading = true
        uploadProgress = 0
        uploadPhaseDescription = "Uploading"
        
        // 更新卡片状态为"分析中"（在 Real API 模式下，后续会用服务器 ID 替换）
        if let taskId = currentRecordingTaskId {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            let timeString = formatter.string(from: startTime)
            
            let updatedTask = TaskItem(
                id: taskId,
                title: "Recording \(timeString)",
                startTime: startTime,
                endTime: nil,
                duration: recordingDuration,
                tags: [],
                status: .analyzing,
                emotionScore: nil,
                speakerCount: nil,
                progressDescription: "Uploading"
            )
            
            print("🔄 [RecordingViewModel] 更新卡片状态为'分析中':")
            print("   - ID: \(updatedTask.id)")
            print("   - 状态: \(updatedTask.status)")
            
            // 通知 TaskListViewModel 更新任务状态
            Task { @MainActor in
                print("📢 [RecordingViewModel] 发送 TaskStatusUpdated 通知（录音停止）")
                NotificationCenter.default.post(
                    name: NSNotification.Name("TaskStatusUpdated"),
                    object: updatedTask
                )
            }
        }
        
        print("📤 [RecordingViewModel] 上传状态已设置为 true")
        print("📤 [RecordingViewModel] 当前环境: \(AppConfig.shared.useMockData ? "Mock" : "Real API")")
        
        // 现在可以使用 Swift 的并发 Task 了，因为我们已经重命名了我们的 Task 结构体
        Task {
            do {
                // 如果是 Mock 模式，直接调用 Gemini API 分析
                if AppConfig.shared.useMockData {
                    print("📦 [RecordingViewModel] ========== Mock 模式流程 ==========")
                    // 使用现有的任务 ID，不创建新任务
                    guard let taskId = self.currentRecordingTaskId else {
                        print("❌ [RecordingViewModel] currentRecordingTaskId 为 nil")
                        await MainActor.run {
                            self.isUploading = false
                            self.uploadProgress = 0
                        }
                        return
                    }
                    
                    let formatter = DateFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    let timeString = formatter.string(from: startTime)
                    
                    await MainActor.run {
                        self.isUploading = false
                        print("✅ [RecordingViewModel] 上传状态已设置为 false")
                    }
                    
                    // 调用 Gemini API 分析
                    let analysisResult = try await GeminiAnalysisService.shared.analyzeAudio(fileURL: audioURL)
                    
                    // 分析完成，更新现有任务状态
                    // 注意：Mock模式下，analysisResult可能没有summary，使用nil
                    let completedTask = TaskItem(
                        id: taskId, // 使用现有的任务 ID
                        title: "Recording \(timeString)",
                        startTime: startTime,
                        endTime: endTime,
                        duration: recordingDuration,
                        tags: analysisResult.risks.map { "#\($0)" },
                        status: .archived,
                        emotionScore: calculateEmotionScore(from: analysisResult),
                        speakerCount: analysisResult.speakerCount,
                        summary: nil // Mock模式下暂时为nil，后续可以从analysisResult中提取
                    )
                    
                    // 通知 TaskListViewModel 更新任务
                    await MainActor.run {
                        print("📢 [RecordingViewModel] 发送 TaskAnalysisCompleted 通知")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("TaskAnalysisCompleted"),
                            object: completedTask
                        )
                    }
                } else {
                    print("🌐 [RecordingViewModel] ========== 真实 API 模式流程 ==========")
                    // 真实 API 模式：上传到服务端
                    print("🌐 [RecordingViewModel] 开始调用 NetworkManager.uploadAudio()")
                    print("🌐 [RecordingViewModel] 文件路径: \(audioURL.path)")
                    
                    let response = try await self.networkManager.uploadAudio(
                        fileURL: audioURL,
                        title: nil,
                        onProgress: { [weak self] pct in
                            Task { @MainActor in
                                self?.uploadProgress = pct
                                let text = pct >= 1.0 ? "Upload complete" : "Uploading \(Int(pct * 100))%"
                                self?.uploadPhaseDescription = text
                                if let taskId = self?.currentRecordingTaskId {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("TaskProgressUpdated"),
                                        object: nil,
                                        userInfo: ["taskId": taskId, "progressDescription": text]
                                    )
                                }
                            }
                        }
                    )
                    
                    print("✅ [RecordingViewModel] 上传成功！")
                    print("📋 [RecordingViewModel] 响应数据:")
                    print("   - sessionId: \(response.sessionId)")
                    print("   - audioId: \(response.audioId)")
                    print("   - title: \(response.title)")
                    print("   - status: \(response.status)")
                    
                    // 更新现有任务，使用服务器返回的 sessionId 和 title
                    // 先删除本地创建的卡片，然后创建新的（使用服务器 ID）
                    if let oldTaskId = self.currentRecordingTaskId {
                        await MainActor.run {
                            // 删除旧卡片
                            print("🗑️ [RecordingViewModel] 删除本地创建的卡片: \(oldTaskId)")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskDeleted"),
                                object: oldTaskId
                            )
                        }
                    }
                    
                    // 使用服务器返回的 sessionId 创建新任务
                    let newTask = TaskItem(
                        id: response.sessionId,
                        title: response.title,
                        startTime: startTime,
                        endTime: nil,
                        duration: recordingDuration,
                        tags: [],
                        status: .analyzing,
                        emotionScore: nil,
                        speakerCount: nil,
                        progressDescription: "Upload complete"
                    )
                    
                    print("📝 [RecordingViewModel] 使用服务器 ID 创建任务:")
                    print("   - ID: \(newTask.id)")
                    print("   - 标题: \(newTask.title)")
                    print("   - 状态: \(newTask.status)")
                    
                    // 更新 currentRecordingTaskId 为服务器返回的 ID
                    self.currentRecordingTaskId = response.sessionId
                    
                    await MainActor.run {
                        // 添加新任务到列表
                        print("📢 [RecordingViewModel] 发送 NewTaskCreated 通知（使用服务器 ID）")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NewTaskCreated"),
                            object: newTask
                        )
                        self.isUploading = false
                        self.uploadProgress = 0
                        print("✅ [RecordingViewModel] 上传状态已设置为 false")
                    }
                    
                    // 开始轮询状态
                    print("🔄 [RecordingViewModel] 开始轮询任务状态...")
                    startPollingStatus(sessionId: response.sessionId)
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
                    self.uploadProgress = 0
                    print("❌ [RecordingViewModel] ========== 上传/分析失败 ==========")
                    print("❌ [RecordingViewModel] 错误类型: \(type(of: error))")
                    print("❌ [RecordingViewModel] 错误信息: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("❌ [RecordingViewModel] 错误域: \(nsError.domain)")
                        print("❌ [RecordingViewModel] 错误码: \(nsError.code)")
                        print("❌ [RecordingViewModel] 用户信息: \(nsError.userInfo)")
                    }
                }
            }
        }
    }
    
    // 本地上传音频文件（用于测试，如《岁月》《沧浪之水》等）
    func uploadLocalFile(fileURL: URL) {
        print("📤 [RecordingViewModel] ========== 本地上传音频 ==========")
        print("📤 [RecordingViewModel] 原始文件路径: \(fileURL.path)")
        
        // 大文件分段提示
        let sizeLimitMB: Int64 = 20
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64, size > sizeLimitMB * 1024 * 1024 {
            let mb = Double(size) / (1024 * 1024)
            print("📎 [RecordingViewModel] 大文件（\(String(format: "%.1f", mb)) MB > \(sizeLimitMB) MB），服务端将自动分段分析")
        }
        
        // security-scoped URL 需在复制前申请访问
        let needsSecurityScope = fileURL.startAccessingSecurityScopedResource()
        defer { if needsSecurityScope { fileURL.stopAccessingSecurityScopedResource() } }
        
        // 复制到临时目录，便于稳定上传
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileName = "upload_\(UUID().uuidString)\(fileURL.pathExtension.isEmpty ? ".m4a" : ".\(fileURL.pathExtension)")"
        let tempURL = tempDir.appendingPathComponent(tempFileName)
        
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: fileURL, to: tempURL)
            print("📁 [RecordingViewModel] 已复制到临时文件: \(tempURL.path)")
        } catch {
            print("❌ [RecordingViewModel] 复制文件失败: \(error)")
            return
        }
        
        let startTime = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeString = formatter.string(from: startTime)
        let taskId = UUID().uuidString
        currentRecordingTaskId = taskId
        
        // 创建本地任务卡片
        let newTask = TaskItem(
            id: taskId,
            title: "Local Upload \(timeString)",
            startTime: startTime,
            endTime: nil,
            duration: 0,
            tags: [],
            status: .analyzing,
            emotionScore: nil,
            speakerCount: nil,
            progressDescription: "Uploading"
        )
        
        Task { @MainActor in
            NotificationCenter.default.post(name: NSNotification.Name("NewTaskCreated"), object: newTask)
        }
        
        isUploading = true
        uploadProgress = 0
        uploadPhaseDescription = "Uploading"
        print("📤 [RecordingViewModel] 上传状态已设置为 true")
        
        Task {
            defer {
                try? FileManager.default.removeItem(at: tempURL)
                Task { @MainActor in
                    self.isUploading = false
                    self.uploadProgress = 0
                    print("✅ [RecordingViewModel] 上传状态已设置为 false")
                }
            }
            do {
                if AppConfig.shared.useMockData {
                    print("📦 [RecordingViewModel] Mock 模式：本地上传分析")
                    let analysisResult = try await GeminiAnalysisService.shared.analyzeAudio(fileURL: tempURL)
                    let completedTask = TaskItem(
                        id: taskId,
                        title: "Local Upload \(timeString)",
                        startTime: startTime,
                        endTime: Date(),
                        duration: 0,
                        tags: analysisResult.risks.map { "#\($0)" },
                        status: .archived,
                        emotionScore: calculateEmotionScore(from: analysisResult),
                        speakerCount: analysisResult.speakerCount,
                        summary: nil
                    )
                    await MainActor.run {
                        NotificationCenter.default.post(name: NSNotification.Name("TaskDeleted"), object: taskId)
                        NotificationCenter.default.post(name: NSNotification.Name("NewTaskCreated"), object: completedTask)
                        NotificationCenter.default.post(name: NSNotification.Name("TaskAnalysisCompleted"), object: completedTask)
                    }
                } else {
                    print("🌐 [RecordingViewModel] 真实 API：开始本地上传（调用 uploadAudio）...")
                    let response = try await networkManager.uploadAudio(
                        fileURL: tempURL,
                        title: "Local Upload \(timeString)",
                        onProgress: { [weak self] pct in
                            Task { @MainActor in
                                self?.uploadProgress = pct
                                let text = pct >= 1.0 ? "Upload complete" : "Uploading \(Int(pct * 100))%"
                                self?.uploadPhaseDescription = text
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("TaskProgressUpdated"),
                                    object: nil,
                                    userInfo: ["taskId": taskId, "progressDescription": text]
                                )
                            }
                        }
                    )
                    print("✅ [RecordingViewModel] 本地上传成功，收到响应 sessionId=\(response.sessionId)")
                    
                    await MainActor.run {
                        NotificationCenter.default.post(name: NSNotification.Name("TaskDeleted"), object: taskId)
                    }
                    
                    let newTask = TaskItem(
                        id: response.sessionId,
                        title: response.title,
                        startTime: startTime,
                        endTime: nil,
                        duration: 0,
                        tags: [],
                        status: .analyzing,
                        emotionScore: nil,
                        speakerCount: nil,
                        progressDescription: "Upload complete"
                    )
                    
                    await MainActor.run {
                        NotificationCenter.default.post(name: NSNotification.Name("NewTaskCreated"), object: newTask)
                    }
                    
                    startPollingStatus(sessionId: response.sessionId)
                }
            } catch {
                print("❌ [RecordingViewModel] 本地上传失败: \(error)")
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TaskAnalysisFailed"),
                        object: taskId,
                        userInfo: ["message": (error as NSError).localizedDescription]
                    )
                }
            }
        }
    }
    
    // 获取文件大小（辅助方法）
    private func getFileSize(url: URL) -> Int64 {
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            return fileSize
        }
        return 0
    }
    
    // 轮询任务状态（真实 API 模式）
    private func startPollingStatus(sessionId: String) {
        print("🔄 [RecordingViewModel] ========== 开始轮询状态 ==========")
        print("🔄 [RecordingViewModel] sessionId: \(sessionId)")
        
        Task {
            // 轮询开始时缓存 Token，避免其他请求（如任务列表刷新）返回 401 时登出导致 Token 被清空、轮询中断
            let cachedToken = KeychainManager.shared.getToken()
            guard let token = cachedToken, !token.isEmpty else {
                print("❌ [RecordingViewModel] 轮询前 Token 为空，请先登录")
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TaskAnalysisFailed"),
                        object: sessionId,
                        userInfo: ["message": "未登录，请先登录后重试"]
                    )
                }
                return
            }
            
            var pollCount = 0
            let maxPolls = 300  // 最多轮询 300 次（含策略阶段，约 15 分钟；大文件分析可达 13 分钟）
            var archivedPollCount = 0  // 达到 archived 后的轮询次数，用于兼容旧服务端
            let maxArchivedPolls = 25  // archived 后最多再轮询 25 次（约 75 秒）等待策略
            var summaryFetched = false  // 避免重复拉取 summary（matching_profiles 或 strategy_* 时拉一次）

            while pollCount < maxPolls {
                do {
                    let waitSeconds: UInt64 = pollCount == 0 ? 8 : 3  // 首次等待 8 秒
                    print("🔄 [RecordingViewModel] 等待 \(waitSeconds) 秒后查询状态（第 \(pollCount + 1)/\(maxPolls) 次）...")
                    try await Task.sleep(nanoseconds: waitSeconds * 1_000_000_000)
                    
                    print("🔄 [RecordingViewModel] 查询任务状态...")
                    let status = try await networkManager.getTaskStatus(sessionId: sessionId, authToken: token)
                    
                    print("📊 [RecordingViewModel] 任务状态:")
                    print("   - status: \(status.status)")
                    print("   - progress: \(status.progress)")
                    print("   - analysisStage: \(status.analysisStage ?? "nil")")
                    if let stage = status.stageDisplayText {
                        print("   - stage: \(stage)")
                        await MainActor.run {
                            self.uploadPhaseDescription = stage
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskProgressUpdated"),
                                object: nil,
                                userInfo: ["taskId": sessionId, "progressDescription": stage]
                            )
                        }
                    }
                    
                    // 提前获取 summary：matching_profiles 或 strategy_* 阶段时拉取一次，供卡片滚动展示
                    let stageForSummary = status.analysisStage ?? ""
                    let hasSummaryStage = stageForSummary == "matching_profiles"
                        || stageForSummary.hasPrefix("strategy_")
                    if hasSummaryStage && !summaryFetched {
                        summaryFetched = true
                        do {
                            let detail = try await networkManager.getTaskDetail(sessionId: sessionId, authToken: token)
                            if let summary = detail.summary, !summary.isEmpty {
                                print("📋 [RecordingViewModel] 提前获取 summary 成功，供卡片滚动展示")
                                await MainActor.run {
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("TaskSummaryAvailable"),
                                        object: nil,
                                        userInfo: ["taskId": sessionId, "summary": summary]
                                    )
                                }
                            }
                        } catch {
                            print("⚠️ [RecordingViewModel] 提前获取 summary 失败: \(error.localizedDescription)")
                            summaryFetched = false
                        }
                    }
                    
                    // archived 后累计轮询次数，用于兼容旧服务端（无 strategy_done）
                    if status.status == "archived" || status.status == "completed" {
                        archivedPollCount += 1
                    }
                    
                    // 处理完成状态：strategy_done 或 completed 或 archived 后超时（兼容旧服务端）
                    let strategyReady = status.analysisStage == "strategy_done"
                    let shouldStop = (status.status == "archived" && strategyReady)
                        || status.status == "completed"
                        || (status.status == "archived" && archivedPollCount >= maxArchivedPolls)
                    if shouldStop {
                        print("✅ [RecordingViewModel] 分析完成！获取详情...")
                        // 分析完成，获取详情并更新（使用缓存的 token）
                        let detail = try await networkManager.getTaskDetail(sessionId: sessionId, authToken: token)
                        
                        print("📋 [RecordingViewModel] 任务详情:")
                        print("   - title: \(detail.title)")
                        print("   - emotionScore: \(detail.emotionScore ?? -1)")
                        print("   - speakerCount: \(detail.speakerCount ?? -1)")
                        print("   - dialogues count: \(detail.dialogues.count)")
                        print("   - risks count: \(detail.risks.count)")
                        
                        // 转换为 TaskItem，包含 summary 和 coverImageUrl
                        // 仅当服务端返回 cover_image_url 时使用，避免请求不存在的图片导致 404
                        let completedTask = TaskItem(
                            id: detail.sessionId,
                            title: detail.title,
                            startTime: detail.startTime,
                            endTime: detail.endTime,
                            duration: detail.duration,
                            tags: detail.tags,
                            status: .archived,
                            emotionScore: detail.emotionScore,
                            speakerCount: detail.speakerCount,
                            summary: detail.summary,
                            coverImageUrl: detail.coverImageUrl
                        )
                        
                        await MainActor.run {
                            print("📢 [RecordingViewModel] 发送 TaskAnalysisCompleted 通知")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskAnalysisCompleted"),
                                object: completedTask
                            )
                            print("✅ [RecordingViewModel] 轮询完成")
                        }
                        break
                    }
                    
                    // 处理失败状态
                    if status.status == "failed" {
                        let message = status.failureReason?.isEmpty == false
                            ? status.failureReason!
                            : "Audio analysis failed, please try again"
                        print("❌ [RecordingViewModel] 分析失败: \(message)")
                        await MainActor.run {
                            print("📢 [RecordingViewModel] 发送 TaskAnalysisFailed 通知")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskAnalysisFailed"),
                                object: sessionId,
                                userInfo: ["message": message]
                            )
                        }
                        break
                    }
                    
                    pollCount += 1
                } catch {
                    print("❌ [RecordingViewModel] 轮询状态失败:")
                    print("   - 错误类型: \(type(of: error))")
                    print("   - 错误信息: \(error.localizedDescription)")
                    // 401 表示认证失效，停止轮询并提示重新登录
                    if (error as NSError).code == 401 {
                        print("❌ [RecordingViewModel] 认证已失效，请重新登录")
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskAnalysisFailed"),
                                object: sessionId,
                                userInfo: ["message": "登录已过期，请重新登录后查看任务"]
                            )
                        }
                        break
                    }
                    // 其他错误继续轮询
                    pollCount += 1
                    if pollCount >= maxPolls {
                        break
                    }
                }
            }
            
            if pollCount >= maxPolls {
                print("⏰ [RecordingViewModel] 轮询超时（已达到最大次数）")
                await MainActor.run {
                    print("📢 [RecordingViewModel] 发送 TaskAnalysisTimeout 通知")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TaskAnalysisTimeout"),
                        object: sessionId,
                        userInfo: ["message": "Analysis timed out, please check task status later"]
                    )
                }
            }
        }
    }
    
    // 根据分析结果计算情绪分数（Mock 模式使用）
    private func calculateEmotionScore(from result: AudioAnalysisResult) -> Int {
        var score = 70
        
        for dialogue in result.dialogues {
            switch dialogue.tone {
            case "愤怒", "焦虑", "紧张":
                score -= 20
            case "轻松", "平静":
                score += 5
            default:
                break
            }
        }
        
        score -= result.risks.count * 10
        return max(0, min(100, score))
    }
    
    // 格式化录音时长
    var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

