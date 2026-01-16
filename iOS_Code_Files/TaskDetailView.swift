import SwiftUI

struct TaskDetailView: View {
    let taskId: String
    @State private var task: Task?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("加载中...")
                    .padding()
            } else if let task = task {
                VStack(alignment: .leading, spacing: 20) {
                    // 任务信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(task.timeRangeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let score = task.emotionScore {
                            Text("情绪分数: \(score)分")
                                .font(.headline)
                                .foregroundColor(emotionColor(for: score))
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
                    
                    Text("详情功能开发中...")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTaskDetail()
        }
    }
    
    private func loadTaskDetail() {
        Task {
            do {
                isLoading = true
                print("📋 [TaskDetailView] 开始加载任务详情，taskId: \(taskId)")
                
                let detail = try await NetworkManager.shared.getTaskDetail(sessionId: taskId)
                
                print("✅ [TaskDetailView] 任务详情加载成功")
                print("   标题: \(detail.title)")
                print("   状态: \(detail.status)")
                print("   对话数量: \(detail.dialogues.count)")
                print("   风险点数量: \(detail.risks.count)")
                
                // 转换为Task模型（用于显示）
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                
                let startTime = dateFormatter.date(from: detail.startTime) ?? Date()
                let endTime = detail.endTime != nil ? dateFormatter.date(from: detail.endTime!) : nil
                
                let taskStatus = TaskStatus(rawValue: detail.status) ?? .archived
                
                await MainActor.run {
                    self.task = Task(
                        id: detail.sessionId,
                        title: detail.title,
                        startTime: startTime,
                        endTime: endTime,
                        duration: detail.duration,
                        tags: detail.tags,
                        status: taskStatus,
                        emotionScore: detail.emotionScore,
                        speakerCount: detail.speakerCount
                    )
                    self.isLoading = false
                }
            } catch {
                print("❌ [TaskDetailView] 加载任务详情失败: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("   错误域: \(nsError.domain)")
                    print("   错误码: \(nsError.code)")
                }
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
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


