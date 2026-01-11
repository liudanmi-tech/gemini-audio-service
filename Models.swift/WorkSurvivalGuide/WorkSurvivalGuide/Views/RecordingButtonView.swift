//
//  RecordingButtonView.swift
//  WorkSurvivalGuide
//
//  录制按钮组件
//

import SwiftUI

struct RecordingButtonView: View {
    @ObservedObject var viewModel: RecordingViewModel
    
    var body: some View {
        Button(action: {
            if viewModel.isRecording {
                viewModel.stopRecordingAndUpload()
            } else {
                viewModel.startRecording()
            }
        }) {
            ZStack {
                Circle()
                    .fill(viewModel.isRecording ? Color.red : Color.blue)
                    .frame(width: viewModel.isRecording ? 80 : 70, height: viewModel.isRecording ? 80 : 70)
                    .shadow(radius: 8)
                    .opacity(viewModel.isRecording ? 0.8 : 1.0)
                
                if viewModel.isRecording {
                    VStack {
                        Image(systemName: "stop.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text(viewModel.formattedTime)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "mic.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
        }
        .disabled(viewModel.isUploading)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isRecording)
    }
}

