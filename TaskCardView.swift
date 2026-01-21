import SwiftUI

struct TaskCardView: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 顶部行：日期和时间
            HStack(alignment: .top, spacing: 0) {
                // 左侧：日期信息
                HStack(alignment: .top, spacing: 8) {
                    // 日期大号数字
                    Text(dayNumber)
                        .font(AppFonts.dateNumber)
                        .foregroundColor(AppColors.dateNumber)
                        .frame(width: 41, height: 35, alignment: .leading)
                    
                    // 星期和年月
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weekday)
                            .font(AppFonts.weekday)
                            .foregroundColor(AppColors.dateNumber)
                            .frame(height: 20)
                        
                        Text(yearMonth)
                            .font(AppFonts.yearMonth)
                            .foregroundColor(AppColors.dateNumber.opacity(0.7))
                            .frame(height: 16)
                            .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // 右侧：时间范围（仅已完成状态显示）
                if task.status == .archived {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(task.timeRangeString)
                            .font(AppFonts.timeRange)
                            .foregroundColor(AppColors.timeText)
                            .frame(height: 20)
                        
                        // 时钟图标
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.timeText)
                            .frame(width: 20, height: 20)
                    }
                    .frame(width: 85, alignment: .trailing)
                }
            }
            
            // 底部：状态标签或标题
            HStack(alignment: .top, spacing: 16) {
                // 状态图标
                StatusIcon(status: task.status)
                    .frame(width: 24, height: 24)
                    .padding(.top, 4)
                
                // 状态文字或标题文本
                if task.status == .archived {
                    // 已完成：显示标题
                    Text(task.title)
                        .font(AppFonts.cardTitle)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // 其他状态：显示状态文字
                    Text(statusText)
                        .font(AppFonts.statusText)
                        .foregroundColor(AppColors.statusText)
                        .opacity(0.637)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.cardBackground)
        .cornerRadius(24)
    }
    
    // 获取日期数字
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: task.startTime)
    }
    
    // 获取星期几
    private var weekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEEE"
        let weekday = formatter.string(from: task.startTime)
        return weekday
    }
    
    // 获取年月
    private var yearMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M"
        return formatter.string(from: task.startTime)
    }
    
    // 获取状态文字
    private var statusText: String {
        switch task.status {
        case .recording:
            return "正在转录语音..."
        case .analyzing:
            return "分析中"
        case .archived:
            return ""
        case .burned:
            return "已焚毁"
        }
    }
}

// 状态图标
struct StatusIcon: View {
    let status: TaskStatus
    
    var body: some View {
        Group {
            switch status {
            case .recording, .analyzing:
                // 分析中/录制中的图标（圆形进度指示器）
                ZStack {
                    Circle()
                        .stroke(AppColors.statusText.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(AppColors.statusText, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                }
            case .archived:
                // 已完成：显示勾选图标
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.Status.completedText)
            case .burned:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
        }
    }
}
