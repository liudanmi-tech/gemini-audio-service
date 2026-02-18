//
//  TaskCardView.swift
//  WorkSurvivalGuide
//
//  任务卡片组件 - 1:1 图片卡片，策略首图填充，底部半透明蒙层展示标题与时间
//

import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    
    private var baseURL: String {
        NetworkManager.shared.getBaseURL()
    }
    
    private var hasCoverImage: Bool {
        guard let url = task.coverImageUrl, !url.isEmpty else { return false }
        return true
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 主内容区：图片或占位
            if hasCoverImage, let url = task.coverImageUrl {
                ImageLoaderView(
                    imageUrl: accessibleImageURL(url),
                    imageBase64: nil,
                    placeholder: "加载中",
                    contentMode: .fill
                )
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
            } else {
                placeholderContent
            }
            
            // 底部约 50% 半透明蒙层
            overlayGradient
            
            // 蒙层上的文字：archived 显示总结（3行内）+时间，其他状态仅显示时间
            VStack(alignment: .leading, spacing: 4) {
                if task.status == .archived {
                    Text(task.overlaySummary)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                HStack {
                    Text(formattedTime)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(task.durationString)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var placeholderContent: some View {
        ZStack {
            placeholderBackground
            VStack(spacing: 8) {
                placeholderIcon
                if !placeholderText.isEmpty {
                    Text(placeholderText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(placeholderTextColor)
                }
            }
        }
    }
    
    private var placeholderBackground: Color {
        switch task.status {
        case .recording:
            return Color(hex: "#E8F4FD")
        case .analyzing:
            return AppColors.Status.analyzingBg
        case .archived:
            return Color(hex: "#F3F4F6")
        case .burned, .failed:
            return Color(hex: "#FEE2E2")
        }
    }
    
    private var placeholderIcon: some View {
        Group {
            switch task.status {
            case .recording:
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#3B82F6"))
            case .analyzing:
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundColor(AppColors.Status.analyzingText)
            case .archived:
                QuotationMarkView(size: 32, color: Color(hex: "#9CA3AF"), opacity: 0.7, isGrayStyle: true)
            case .burned, .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#DC2626"))
            }
        }
    }
    
    private var placeholderText: String {
        switch task.status {
        case .recording:
            return "录音上传中"
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
    
    private var placeholderTextColor: Color {
        switch task.status {
        case .recording:
            return Color(hex: "#3B82F6").opacity(0.9)
        case .analyzing:
            return AppColors.Status.analyzingText
        case .archived:
            return Color(hex: "#6B7280")
        case .burned, .failed:
            return Color(hex: "#DC2626").opacity(0.9)
        }
    }
    
    private var overlayGradient: some View {
        VStack {
            Spacer()
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0),
                    Color.black.opacity(0.65)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 100)
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: task.startTime)
    }
    
    private func accessibleImageURL(_ url: String) -> String {
        if url.contains("/api/v1/images/") || url.hasPrefix("http") {
            return url
        }
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return "\(base)/api/v1/images/\(task.id)/0"
    }
}
