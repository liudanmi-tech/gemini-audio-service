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
        print("🎤 [RecordingViewModel] ========== 开始录制 ==========")
        print("🎤 [RecordingViewModel] 调用 AudioRecorderService.startRecording()")
        audioRecorder.startRecording()
        isRecording = true
        recordingTime = 0
        print("🎤 [RecordingViewModel] ✅ 录制状态已设置为 true")
        
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
        print("📁 [RecordingViewModel] 音频文件大小: \(getFileSize(url: audioURL)) 字节")
        
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
        
        print("📤 [RecordingViewModel] 上传状态已设置为 true")
        print("📤 [RecordingViewModel] 当前环境: \(AppConfig.shared.useMockData ? "Mock" : "Real API")")
        
        // 现在可以使用 Swift 的并发 Task 了，因为我们已经重命名了我们的 Task 结构体
        Task {
            do {
                // 如果是 Mock 模式，直接调用 Gemini API 分析
                if AppConfig.shared.useMockData {
                    print("📦 [RecordingViewModel] ========== Mock 模式流程 ==========")
                    // 创建新任务，状态为"分析中"
                    let formatter = DateFormatter()
                    formatter.dateStyle = .none
                    formatter.timeStyle = .short
                    let timeString = formatter.string(from: startTime)
                    
                    let newTask = TaskItem(
                        id: UUID().uuidString,
                        title: "录音 \(timeString)",
                        startTime: startTime,
                        endTime: endTime,
                        duration: recordingDuration,
                        tags: [],
                        status: .analyzing,
                        emotionScore: nil,
                        speakerCount: nil
                    )
                    
                    print("📝 [RecordingViewModel] 创建新任务:")
                    print("   - ID: \(newTask.id)")
                    print("   - 标题: \(newTask.title)")
                    print("   - 状态: \(newTask.status)")
                    
                    // 通知 TaskListViewModel 添加新任务
                    await MainActor.run {
                        print("📢 [RecordingViewModel] 发送 NewTaskCreated 通知")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NewTaskCreated"),
                            object: newTask
                        )
                        self.isUploading = false
                        print("✅ [RecordingViewModel] 上传状态已设置为 false")
                    }
                    
                    // 调用 Gemini API 分析
                    let analysisResult = try await GeminiAnalysisService.shared.analyzeAudio(fileURL: audioURL)
                    
                    // 分析完成，更新任务状态
                    let completedTask = TaskItem(
                        id: newTask.id,
                        title: newTask.title,
                        startTime: newTask.startTime,
                        endTime: newTask.endTime,
                        duration: newTask.duration,
                        tags: analysisResult.risks.map { "#\($0)" },
                        status: .archived,
                        emotionScore: calculateEmotionScore(from: analysisResult),
                        speakerCount: analysisResult.speakerCount
                    )
                    
                    // 通知 TaskListViewModel 更新任务
                    await MainActor.run {
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
                        title: nil
                    )
                    
                    print("✅ [RecordingViewModel] 上传成功！")
                    print("📋 [RecordingViewModel] 响应数据:")
                    print("   - sessionId: \(response.sessionId)")
                    print("   - audioId: \(response.audioId)")
                    print("   - title: \(response.title)")
                    print("   - status: \(response.status)")
                    
                    // 创建新任务，状态为"分析中"
                    let newTask = TaskItem(
                        id: response.sessionId,
                        title: response.title,
                        startTime: startTime,
                        endTime: nil,
                        duration: recordingDuration,
                        tags: [],
                        status: .analyzing,
                        emotionScore: nil,
                        speakerCount: nil
                    )
                    
                    print("📝 [RecordingViewModel] 创建新任务:")
                    print("   - ID: \(newTask.id)")
                    print("   - 标题: \(newTask.title)")
                    print("   - 状态: \(newTask.status)")
                    
                    await MainActor.run {
                        // 添加新任务到列表
                        print("📢 [RecordingViewModel] 发送 NewTaskCreated 通知")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NewTaskCreated"),
                            object: newTask
                        )
                        self.isUploading = false
                        print("✅ [RecordingViewModel] 上传状态已设置为 false")
                    }
                    
                    // 开始轮询状态
                    print("🔄 [RecordingViewModel] 开始轮询任务状态...")
                    startPollingStatus(sessionId: response.sessionId)
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
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
            var pollCount = 0
            let maxPolls = 120  // 最多轮询 120 次（6分钟，因为音频分析可能需要更长时间）
            
            while pollCount < maxPolls {
                do {
                    print("🔄 [RecordingViewModel] 等待 3 秒后查询状态（第 \(pollCount + 1)/\(maxPolls) 次）...")
                    try await Task.sleep(nanoseconds: 3_000_000_000)  // 等待 3 秒
                    
                    print("🔄 [RecordingViewModel] 查询任务状态...")
                    let status = try await networkManager.getTaskStatus(sessionId: sessionId)
                    
                    print("📊 [RecordingViewModel] 任务状态:")
                    print("   - status: \(status.status)")
                    print("   - progress: \(status.progress)")
                    print("   - estimatedTimeRemaining: \(status.estimatedTimeRemaining)")
                    
                    // 处理完成状态
                    if status.status == "archived" || status.status == "completed" {
                        print("✅ [RecordingViewModel] 分析完成！获取详情...")
                        // 分析完成，获取详情并更新
                        let detail = try await networkManager.getTaskDetail(sessionId: sessionId)
                        
                        print("📋 [RecordingViewModel] 任务详情:")
                        print("   - title: \(detail.title)")
                        print("   - emotionScore: \(detail.emotionScore ?? -1)")
                        print("   - speakerCount: \(detail.speakerCount ?? -1)")
                        print("   - dialogues count: \(detail.dialogues.count)")
                        print("   - risks count: \(detail.risks.count)")
                        
                        // 转换为 TaskItem
                        let completedTask = TaskItem(
                            id: detail.sessionId,
                            title: detail.title,
                            startTime: detail.startTime,
                            endTime: detail.endTime,
                            duration: detail.duration,
                            tags: detail.tags,
                            status: .archived,
                            emotionScore: detail.emotionScore,
                            speakerCount: detail.speakerCount
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
                        print("❌ [RecordingViewModel] 分析失败")
                        await MainActor.run {
                            print("📢 [RecordingViewModel] 发送 TaskAnalysisFailed 通知")
                            NotificationCenter.default.post(
                                name: NSNotification.Name("TaskAnalysisFailed"),
                                object: sessionId,
                                userInfo: ["message": "音频分析失败，请重试"]
                            )
                        }
                        break
                    }
                    
                    pollCount += 1
                } catch {
                    print("❌ [RecordingViewModel] 轮询状态失败:")
                    print("   - 错误类型: \(type(of: error))")
                    print("   - 错误信息: \(error.localizedDescription)")
                    // 继续轮询，不要立即退出
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
                        userInfo: ["message": "分析超时，请稍后查看任务状态"]
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

