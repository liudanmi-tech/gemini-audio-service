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
        print("🎤 [AudioRecorderService] ========== 开始录音 ==========")
        print("🎤 [AudioRecorderService] 请求麦克风权限...")
        // 请求麦克风权限
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            guard granted else {
                print("❌ [AudioRecorderService] 麦克风权限被拒绝")
                return
            }
            
            print("✅ [AudioRecorderService] 麦克风权限已授予")
            DispatchQueue.main.async {
                self?._startRecording()
            }
        }
    }
    
    private func _startRecording() {
        print("🎤 [AudioRecorderService] 开始创建录音文件...")
        // 创建录音文件路径
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        recordingURL = audioFilename
        
        print("📁 [AudioRecorderService] 录音文件路径: \(audioFilename.path)")
        
        // 录音设置
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        print("⚙️ [AudioRecorderService] 录音设置:")
        print("   - 格式: MPEG4AAC")
        print("   - 采样率: 44100 Hz")
        print("   - 声道数: 2")
        print("   - 质量: High")
        
        do {
            // 创建录音器
            print("🎤 [AudioRecorderService] 创建 AVAudioRecorder...")
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            
            print("🎤 [AudioRecorderService] 开始录音...")
            audioRecorder?.record()
            
            // 更新状态
            isRecording = true
            recordingTime = 0
            
            // 启动定时器
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingTime += 0.1
            }
            
            print("✅ [AudioRecorderService] 录音已启动")
            print("✅ [AudioRecorderService] 录音文件: \(audioFilename.path)")
        } catch {
            print("❌ [AudioRecorderService] 录音启动失败:")
            print("   - 错误类型: \(type(of: error))")
            print("   - 错误信息: \(error.localizedDescription)")
        }
    }
    
    // 停止录音
    func stopRecording() -> URL? {
        print("🛑 [AudioRecorderService] ========== 停止录音 ==========")
        print("🛑 [AudioRecorderService] 当前录制时长: \(recordingTime) 秒")
        
        audioRecorder?.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        
        let url = recordingURL
        recordingURL = nil
        
        if let url = url {
            print("✅ [AudioRecorderService] 录音已停止")
            print("📁 [AudioRecorderService] 返回文件路径: \(url.path)")
            
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: url.path) {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let fileSize = attributes[.size] as? Int64 {
                    print("📊 [AudioRecorderService] 文件大小: \(fileSize) 字节 (\(Double(fileSize) / 1024.0 / 1024.0) MB)")
                }
            } else {
                print("⚠️ [AudioRecorderService] 警告：文件不存在！")
            }
        } else {
            print("❌ [AudioRecorderService] 错误：recordingURL 为 nil")
        }
        
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
            print("✅ [AudioRecorderService] 录音完成（delegate 回调）")
        } else {
            print("❌ [AudioRecorderService] 录音失败（delegate 回调）")
        }
    }
}

