import SwiftUI

struct TaskCardView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和状态
            HStack {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 状态指示器
                StatusIndicator(status: task.status)
            }
            
            // 时间和时长
            HStack {
                Text(task.timeRangeString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(task.durationString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 标签
            if !task.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(task.tags, id: \.self) { tag in
                            TagView(text: tag)
                        }
                    }
                }
            }
            
            // 情绪分数
            if let score = task.emotionScore {
                HStack {
                    Text("情绪分数:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(score)分")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(emotionColor(for: score))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // 根据情绪分数返回颜色
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

// 状态指示器
struct StatusIndicator: View {
    let status: TaskStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .recording:
            return .red
        case .analyzing:
            return .orange
        case .archived:
            return .green
        case .burned:
            return .gray
        }
    }
    
    private var statusText: String {
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
}

// 标签视图
struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tagColor)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
    
    private var tagColor: Color {
        if text.contains("PUA") || text.contains("风险") {
            return .red
        } else if text.contains("急躁") || text.contains("焦虑") {
            return .orange
        } else {
            return .blue
        }
    }
}

