//
//  DeviceSelectionSheet.swift
//  WorkSurvivalGuide
//
//  选择录音设备 - 手机麦克风或蓝牙设备（智能眼镜等）
//

import SwiftUI
import AVFoundation

struct DeviceSelectionSheet: View {
    @ObservedObject var deviceManager = BluetoothDeviceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if deviceManager.availableBluetoothInputs.isEmpty {
                    // 无蓝牙设备，显示引导
                    VStack(spacing: 24) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 60))
                            .foregroundColor(AppColors.secondaryText)
                        
                        Text("未发现蓝牙设备")
                            .font(AppFonts.cardTitle)
                            .foregroundColor(AppColors.primaryText)
                        
                        Text("请先在 设置 > 蓝牙 中配对您的智能眼镜，配对成功后返回此处选择。")
                            .font(AppFonts.time)
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        
                        Button("去设置") {
                            deviceManager.openSettings()
                            dismiss()
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .cornerRadius(10)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 有蓝牙设备，显示列表
                    List {
                        Section {
                            DeviceOptionRow(
                                title: "手机麦克风",
                                subtitle: "使用 iPhone 麦克风录音",
                                isSelected: deviceManager.selectedInputId == nil
                            ) {
                                deviceManager.selectInput(nil)
                            }
                        }
                        
                        Section {
                            ForEach(deviceManager.availableBluetoothInputs, id: \.portName) { port in
                                DeviceOptionRow(
                                    title: port.portName,
                                    subtitle: portTypeLabel(port.portType),
                                    isSelected: deviceManager.selectedInputId == deviceManager.identifier(for: port)
                                ) {
                                    deviceManager.selectInput(port)
                                }
                            }
                        } header: {
                            Text("蓝牙设备")
                        }
                    }
                }
            }
            .navigationTitle("选择录音设备")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            deviceManager.refreshInputs()
        }
    }
    
    private func portTypeLabel(_ portType: AVAudioSession.Port) -> String {
        switch portType {
        case .bluetoothHFP: return "蓝牙耳机/眼镜"
        case .bluetoothLE: return "蓝牙设备"
        default: return "蓝牙"
        }
    }
}

struct DeviceOptionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppColors.primaryText)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.secondaryText)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color.blue)
                }
            }
        }
    }
}
