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

