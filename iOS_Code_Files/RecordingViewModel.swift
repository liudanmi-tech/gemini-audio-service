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
                    
                    // 检查是否是 401 错误
                    if let nsError = error as NSError?, nsError.code == 401 {
                        print("🔐 [RecordingViewModel] 检测到 401 错误，应该已自动清除登录状态")
                        // 确保在主线程上清除登录状态（虽然 NetworkManager 已经处理了，但这里再确认一次）
                        AuthManager.shared.logout()
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


