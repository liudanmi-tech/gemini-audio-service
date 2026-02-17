//
//  BluetoothDeviceManager.swift
//  WorkSurvivalGuide
//
//  管理蓝牙录音设备选择，支持智能眼镜等蓝牙麦克风
//

import AVFoundation
import Combine
import UIKit

class BluetoothDeviceManager: ObservableObject {
    static let shared = BluetoothDeviceManager()
    
    /// 当前选中的蓝牙输入标识（portName，nil 表示手机麦克风）
    @Published private(set) var selectedInputId: String?
    
    /// 是否已连接蓝牙设备（用户选择了蓝牙且该设备仍在可用列表中）
    @Published private(set) var isBluetoothConnected: Bool = false
    
    /// 可用的蓝牙输入列表（HFP、LE 等带麦克风的设备）
    @Published private(set) var availableBluetoothInputs: [AVAudioSessionPortDescription] = []
    
    private let selectedInputKey = "BluetoothDeviceManager.selectedInputId"
    
    private init() {
        loadSelectedInput()
        refreshInputs()
        setupRouteChangeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 刷新输入列表
    
    /// 刷新可用的蓝牙输入列表，应在 sheet 显示时调用
    func refreshInputs() {
        let session = AVAudioSession.sharedInstance()
        guard let inputs = session.availableInputs else {
            availableBluetoothInputs = []
            updateConnectionState()
            return
        }
        
        availableBluetoothInputs = inputs.filter { port in
            port.portType == .bluetoothHFP || port.portType == .bluetoothLE
        }
        
        // 若之前选中的设备已不在列表中，清除选择
        if let id = selectedInputId, !availableBluetoothInputs.contains(where: { identifier(for: $0) == id }) {
            selectedInputId = nil
            UserDefaults.standard.removeObject(forKey: selectedInputKey)
            try? session.setPreferredInput(nil)
        }
        
        updateConnectionState()
    }
    
    /// 端口唯一标识，供外部比较选中状态
    func identifier(for port: AVAudioSessionPortDescription) -> String {
        "\(port.portName)_\(port.portType.rawValue)"
    }
    
    // MARK: - 选择输入
    
    /// 选择录音输入设备，nil 表示使用手机麦克风
    func selectInput(_ port: AVAudioSessionPortDescription?) {
        let session = AVAudioSession.sharedInstance()
        
        do {
            if let port = port {
                try session.setPreferredInput(port)
                selectedInputId = identifier(for: port)
                UserDefaults.standard.set(selectedInputId, forKey: selectedInputKey)
                print("📱 [BluetoothDeviceManager] 已选择蓝牙输入: \(port.portName)")
            } else {
                try session.setPreferredInput(nil)
                selectedInputId = nil
                UserDefaults.standard.removeObject(forKey: selectedInputKey)
                print("📱 [BluetoothDeviceManager] 已切换为手机麦克风")
            }
            isBluetoothConnected = port != nil
        } catch {
            print("❌ [BluetoothDeviceManager] 设置输入失败: \(error)")
            selectedInputId = nil
            isBluetoothConnected = false
        }
    }
    
    // MARK: - 获取当前应使用的输入（供 AudioRecorderService 调用）
    
    /// 返回当前应使用的蓝牙输入，若未选择或设备不可用则返回 nil（使用手机麦克风）
    func preferredInputForRecording() -> AVAudioSessionPortDescription? {
        guard let id = selectedInputId else { return nil }
        return availableBluetoothInputs.first { identifier(for: $0) == id }
    }
    
    // MARK: - 打开设置
    
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Private
    
    private func loadSelectedInput() {
        selectedInputId = UserDefaults.standard.string(forKey: selectedInputKey)
    }
    
    private func updateConnectionState() {
        if let id = selectedInputId, availableBluetoothInputs.contains(where: { identifier(for: $0) == id }) {
            isBluetoothConnected = true
        } else {
            isBluetoothConnected = false
        }
    }
    
    private func setupRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshInputs()
        }
    }
}
