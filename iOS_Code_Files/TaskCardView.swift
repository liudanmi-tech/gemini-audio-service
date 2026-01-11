import SwiftUI

struct TaskCardView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题和时间行
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    // 标题
                    Text(task.title)
                        .font(AppFonts.cardTitle)
                        .foregroundColor(AppColors.primaryText)
                    
                    // 时间（带时钟图标）
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.secondaryText)
                        Text(task.timeRangeString)
                            .font(AppFonts.time)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
                
                // 状态标签
                StatusBadge(status: task.status)
            }
            
            // 标签行
            if !task.tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(task.tags, id: \.self) { tag in
                        TagView(text: tag)
                    }
                }
            }
        }
        .padding(17)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1.38)
        )
        .cornerRadius(12)
        .shadow(color: AppColors.border, radius: 0, x: 3, y: 3)
    }
}

// 状态标签
struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        Text(statusText)
            .font(AppFonts.statusLabel)
            .foregroundColor(textColor)
            .padding(.horizontal, 8.69)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 0.69)
            )
            .clipShape(Capsule())
    }
    
    private var backgroundColor: Color {
        switch status {
        case .recording:
            return AppColors.Status.analyzingBg
        case .analyzing:
            return AppColors.Status.analyzingBg
        case .archived:
            return AppColors.Status.completedBg
        case .burned:
            return Color.gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .recording:
            return AppColors.Status.analyzingText
        case .analyzing:
            return AppColors.Status.analyzingText
        case .archived:
            return AppColors.Status.completedText
        case .burned:
            return Color.gray
        }
    }
    
    private var borderColor: Color {
        switch status {
        case .recording:
            return AppColors.Status.analyzingBorder
        case .analyzing:
            return AppColors.Status.analyzingBorder
        case .archived:
            return AppColors.Status.completedBorder
        case .burned:
            return Color.gray.opacity(0.3)
        }
    }
    
    private var statusText: String {
        switch status {
        case .recording:
            return "录制中"
        case .analyzing:
            return "分析中"
        case .archived:
            return "已完成"
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
            .font(AppFonts.tagText)
            .foregroundColor(AppColors.Tag.tagText)
            .padding(.horizontal, 8.69)
            .padding(.vertical, 1.99)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AppColors.Tag.tagBorder, lineWidth: 0.69)
            )
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        if text.contains("焦虑") || text.lowercased().contains("anxiety") {
            return AppColors.Tag.anxietyBg
        } else if text.contains("PUA") || text.contains("预警") {
            return AppColors.Tag.puaBg
        } else if text.contains("创意") || text.contains("创意") {
            return AppColors.Tag.creativeBg
        } else {
            // 默认颜色，根据标签内容智能判断
            let lowerText = text.lowercased()
            if lowerText.contains("pua") || lowerText.contains("预警") || lowerText.contains("风险") {
                return AppColors.Tag.puaBg
            } else if lowerText.contains("焦虑") || lowerText.contains("急躁") {
                return AppColors.Tag.anxietyBg
            } else {
                return AppColors.Tag.creativeBg
            }
        }
    }
}


