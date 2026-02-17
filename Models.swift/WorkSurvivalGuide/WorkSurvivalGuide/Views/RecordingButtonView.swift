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
            // 本地上传按钮
            Button(action: onUploadTap) {
                ZStack {
                    Circle()
                        .fill(AppColors.recordButton.opacity(0.9))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(AppColors.recordButtonBorder, lineWidth: 2.5)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .disabled(viewModel.isRecording || viewModel.isUploading)
            
            // 录音按钮
            Button(action: {
                if viewModel.isRecording {
                    viewModel.stopRecordingAndUpload()
                } else {
                    viewModel.startRecording()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(AppColors.recordButton)
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(AppColors.recordButtonBorder, lineWidth: 3.45)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    if viewModel.isRecording {
                        VStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 8, height: 17.33)
                        }
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                    }
                }
            }
            .disabled(viewModel.isUploading)
        }
    }
}
