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
        print("🛑 [RecordingViewModel] ========== 停止录制并上传 ==========")
        print("🛑 [RecordingViewModel] 当前录制时长: \(recordingTime) 秒")
        
        guard let audioURL = audioRecorder.stopRecording() else {
            print("❌ [RecordingViewModel] 停止录制失败，无法获取音频文件")
            return
        }
        
        isRecording = false
        timer?.invalidate()
        timer = nil
        isUploading = true
        
        print("🛑 [RecordingViewModel] 调用 AudioRecorderService.stopRecording()")
        print("✅ [RecordingViewModel] 录制停止成功")
        print("📁 [RecordingViewModel] 音频文件路径: \(audioURL.path)")
        
        // 获取文件大小
        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: audioURL.path),
           let fileSize = fileAttributes[.size] as? Int64 {
            print("📁 [RecordingViewModel] 音频文件大小: \(fileSize) 字节")
        }
        
        // 计算录制时长
        let duration = Int(recordingTime)
        print("⏱️ [RecordingViewModel] 录制时长: \(duration) 秒")
        print("⏱️ [RecordingViewModel] 开始时间: \(Date())")
        print("⏱️ [RecordingViewModel] 结束时间: \(Date())")
        
        print("📤 [RecordingViewModel] 上传状态已设置为 true")
        print("🌐 [RecordingViewModel] 当前环境: Real API")
        print("🌐 [RecordingViewModel] ========== 真实 API 模式流程 ==========")
        print("🌐 [RecordingViewModel] 开始调用 NetworkManager.uploadAudio()")
        print("🌐 [RecordingViewModel] 文件路径: \(audioURL.path)")
        
        Task {
            do {
                let response = try await networkManager.uploadAudio(fileURL: audioURL)
                await MainActor.run {
                    self.isUploading = false
                    print("✅ [RecordingViewModel] 上传成功: \(response.sessionId)")
                    // 发送通知，让 TaskListViewModel 刷新列表
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TaskUploaded"),
                        object: nil
                    )
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
    
    // 格式化录音时长
    var formattedTime: String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

