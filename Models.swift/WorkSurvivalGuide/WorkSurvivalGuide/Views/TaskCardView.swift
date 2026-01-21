//
//  TaskCardView.swift
//  WorkSurvivalGuide
//
//  任务卡片组件 - 按照Figma设计稿精确实现
//

import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 23.99) { // 精确按照 Figma: gap: 23.99053192138672px
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
                    VStack(alignment: .trailing, spacing: 1.99) { // 精确按照 Figma: gap 1.9938240051269531px
                        Text(task.timeRangeString)
                            .font(AppFonts.timeRange)
                            .foregroundColor(AppColors.timeText)
                            .tracking(-0.7) // 精确按照 Figma: letterSpacing -4.999999914850507% (14px * -5% ≈ -0.7pt)
                            .frame(height: 19.99) // 精确按照 Figma: height 19.99px
                        
                        // 时钟图标
                        Image(systemName: "clock")
                            .font(.system(size: 19.99))
                            .foregroundColor(AppColors.timeText)
                            .frame(width: 19.99, height: 19.99) // 精确按照 Figma: 19.99 x 19.99px
                    }
                    .frame(width: 84.99, height: 41.98, alignment: .trailing) // 精确按照 Figma: width 84.99px, height 41.98px
                }
            }
            
            // 底部：状态标签或标题
            HStack(alignment: .top, spacing: 16) {
                // 状态文字或标题文本
                if task.status == .archived {
                    // 已完成：显示灰色引号和精炼后的标题（从summary中提取，30字以内）
                    // 按照 Figma 设计：灰色引号 + 标题文本，自适应高度
                    HStack(alignment: .top, spacing: 15.99) { // 精确按照 Figma: gap 15.993680953979492px
                        // 灰色引号（样式和分析中状态完全一致，只是颜色改为 #E5E7EB）
                        QuotationMarkView(
                            size: 23.99, // 精确按照 Figma: 23.99 x 23.99
                            color: Color(hex: "#E5E7EB"), // 灰色引号颜色
                            opacity: 0.637, // 和分析中状态相同的透明度
                            isGrayStyle: true // 使用灰色引号样式
                        )
                        .padding(.top, 4) // 与文本对齐
                        
                        // 标题文本（自适应高度，不截断）
                        Text(displayTitle)
                            .font(AppFonts.cardTitle) // 18px，Nunito Medium
                            .foregroundColor(AppColors.primaryText) // #4A4A4A
                            .fixedSize(horizontal: false, vertical: true) // 自适应高度，不截断
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading) // 多行文本左对齐
                    }
                } else {
                    // 其他状态：只显示引号和状态文字（不显示等待圆圈）
                    HStack(spacing: 15.99) { // 根据 Figma: gap 15.993680953979492px
                        // 引号图标（根据 Figma 设计）
                        QuotationMarkView(
                            size: 23.99, // 根据 Figma: 23.99 x 23.99
                            color: AppColors.statusText,
                            opacity: 0.637
                        )
                        
                        // 状态文字
                        Text(statusText)
                            .font(AppFonts.statusText)
                            .foregroundColor(AppColors.statusText)
                            .opacity(0.637)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.top, 23.99) // 精确按照 Figma: padding top 23.99053192138672px
        .padding(.horizontal, 23.99) // 精确按照 Figma: padding horizontal 23.990520477294922px
        .padding(.bottom, 0) // 精确按照 Figma: padding bottom 0px
        .frame(maxWidth: .infinity, minHeight: 145, alignment: .leading) // 默认高度 145px
        .background(AppColors.cardBackground)
        .cornerRadius(24) // 精确按照 Figma: borderRadius: 24px
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
        case .failed:
            return "分析失败"
        }
    }
    
    // 获取显示标题（确保始终有值）
    private var displayTitle: String {
        let refined = task.refinedTitle
        return refined.isEmpty ? task.title : refined
    }
}

// 状态图标（仅用于已完成状态，recording 和 analyzing 状态不使用图标）
struct StatusIcon: View {
    let status: TaskStatus
    
    var body: some View {
        Group {
            switch status {
            case .recording, .analyzing:
                // 这些状态不再显示图标，只显示引号和文字
                EmptyView()
            case .archived:
                // 已完成：显示勾选图标
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.Status.completedText)
            case .burned, .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
        }
    }
}
