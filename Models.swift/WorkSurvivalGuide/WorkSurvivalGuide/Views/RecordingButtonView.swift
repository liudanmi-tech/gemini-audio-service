//
//  RecordingButtonView.swift
//  WorkSurvivalGuide
//
//  录制按钮组件 - 按照Figma设计稿实现
//

import SwiftUI

struct RecordingButtonView: View {
    @ObservedObject var viewModel: RecordingViewModel
    var onUploadTap: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 16) {
            // 本地上传按钮 - 毛玻璃效果 + 边缘部分亮变
            Button(action: onUploadTap) {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(edgeBrighteningGradient, lineWidth: 2)
                        )
                    
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .disabled(viewModel.isRecording || viewModel.isUploading)
            
            // 录音按钮 - 毛玻璃效果 + 边缘部分亮变
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecordingAndUpload()
                } else {
                    viewModel.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(edgeBrighteningGradient, lineWidth: 2.5)
                        )
                    
                    if viewModel.isRecording {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(viewModel.isUploading)
        }
    }
    
    /// 边缘部分亮变：上下弧亮，左右渐隐（非全圈亮）
    private var edgeBrighteningGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color.white.opacity(0.65),
                Color.white.opacity(0.15),
                Color.white.opacity(0.65),
                Color.white.opacity(0.15)
            ],
            center: .center
        )
    }
}
