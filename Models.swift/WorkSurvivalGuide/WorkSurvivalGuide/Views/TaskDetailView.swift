//
//  TaskDetailView.swift
//  WorkSurvivalGuide
//
//  任务详情视图（简化版）
//

import SwiftUI

struct TaskDetailView: View {
    let task: TaskItem  // 直接传递 task 对象，而不是 taskId
    @State private var detail: TaskDetailResponse?
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 任务信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(task.timeRangeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("时长: \(task.durationString)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let score = task.emotionScore {
                        Text("情绪分数: \(score)分")
                            .font(.headline)
                            .foregroundColor(emotionColor(for: score))
                    }
                    
                    if let speakerCount = task.speakerCount {
                        Text("说话人数: \(speakerCount)人")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // 标签
                if !task.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(task.tags, id: \.self) { tag in
                                TagView(text: tag)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 状态信息
                VStack(alignment: .leading, spacing: 8) {
                    Text("状态")
                        .font(.headline)
                    Text(statusText(for: task.status))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // 对话列表（如果有详情）
                if let detail = detail, !detail.dialogues.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("对话内容")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(Array(detail.dialogues.enumerated()), id: \.offset) { index, dialogue in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(dialogue.speaker)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if let timestamp = dialogue.timestamp {
                                        Text(formatTime(timestamp))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Text(dialogue.content)
                                    .font(.body)
                                
                                Text("语气: \(dialogue.tone)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
                
                // 风险点列表（如果有详情）
                if let detail = detail, !detail.risks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("风险点")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(detail.risks, id: \.self) { risk in
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(risk)
                                    .font(.body)
                                Spacer()
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
                
                if isLoading {
                    ProgressView("加载详情中...")
                        .padding()
                } else if detail == nil && task.status == .archived {
                    // 如果任务已归档但没有详情，尝试加载
                    Text("点击加载详情")
                        .foregroundColor(.blue)
                        .onTapGesture {
                            loadTaskDetail()
                        }
                        .padding()
                }
            }
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 如果任务已归档，自动加载详情
            if task.status == .archived && !AppConfig.shared.useMockData {
                loadTaskDetail()
            }
        }
    }
    
    private func loadTaskDetail() {
        isLoading = true
        
        Task {
            do {
                let taskDetail = try await NetworkManager.shared.getTaskDetail(sessionId: task.id)
                await MainActor.run {
                    self.detail = taskDetail
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("加载详情失败: \(error)")
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    private func statusText(for status: TaskStatus) -> String {
        switch status {
        case .recording:
            return "录制中"
        case .analyzing:
            return "分析中"
        case .archived:
            return "已归档"
        case .burned:
            return "已焚毁"
        }
    }
    
    private func emotionColor(for score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

