//
//  TaskCardView.swift
//  WorkSurvivalGuide
//
//  任务卡片组件 - 1:1 图片卡片，策略首图填充，底部半透明蒙层展示标题与时间
//  1-6 步：图标+状态在卡片中央；7-12 步：summary 由下至上滚动，阶段 badge 在右上角
//

import SwiftUI

struct TaskCardView: View {
    let task: TaskItem
    /// 封面图 404 时置为 true，切换为占位内容
    @State private var coverLoadFailed = false
    
    private var baseURL: String {
        NetworkManager.shared.getBaseURL()
    }
    
    private var hasCoverImage: Bool {
        guard let url = task.coverImageUrl, !url.isEmpty else { return false }
        return true
    }
    
    /// 7-12 步：有 summary 且在分析中、无封面图时，显示滚动 summary
    private var hasScrollingSummary: Bool {
        task.status == .analyzing
            && (task.summary != nil && !(task.summary?.isEmpty ?? true))
            && !hasCoverImage
    }
    
    /// 是否处于策略阶段（7-12 步），用于右上角 badge
    private var isStrategyPhase: Bool {
        guard let stage = task.progressDescription else { return false }
        return stage.contains("Identifying scene")
            || stage.contains("Matching skills") || stage.contains("Matched")
            || stage.contains("Processing skills")
            || stage.contains("Generating images")
            || stage.contains("Strategy ready")
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 主内容区：图片 / 滚动 summary / 占位
            if hasCoverImage, let url = task.coverImageUrl, !coverLoadFailed {
                ImageLoaderView(
                    imageUrl: accessibleImageURL(url),
                    imageBase64: nil,
                    placeholder: "Loading",
                    contentMode: .fill,
                    onLoadFailed: { coverLoadFailed = true }
                )
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .clipped()
                .onChange(of: task.id) { _ in coverLoadFailed = false }
            } else if hasScrollingSummary, let summary = task.summary {
                scrollingSummaryContent(summary: summary)
            } else {
                placeholderContent
            }
            
            // 底部渐变蒙层
            overlayGradient
            
            // 7-12 步：右上角阶段 badge，不遮挡 summary
            if hasScrollingSummary && isStrategyPhase, let stage = task.progressDescription {
                VStack {
                    Text(stage)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
            }
            
            // 文字总结区域：毛玻璃 + 总结/时间/时长
            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    if task.status == .archived {
                        Text(task.cardTitle ?? task.refinedTitle)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
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
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.25))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    /// 7-12 步：summary 由下至上滚动展示，字体样式参照截图 2
    @ViewBuilder
    private func scrollingSummaryContent(summary: String) -> some View {
        ZStack {
            placeholderBackground
            ScrollingSummaryView(text: summary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 44)
                .padding(.bottom, 8)
                .clipped()
        }
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
            return Color(hex: "#1E3A5F").opacity(0.9)
        case .analyzing:
            return Color(hex: "#4A3F00").opacity(0.9)
        case .archived:
            return Color(white: 0.15)
        case .burned, .failed:
            return Color(hex: "#4A1C1C").opacity(0.9)
        }
    }
    
    private var placeholderIcon: some View {
        Group {
            switch task.status {
            case .recording:
                Image(systemName: "icloud.and.arrow.up")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#60A5FA"))
            case .analyzing:
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#FBBF24"))
            case .archived:
                QuotationMarkView(size: 32, color: Color.white.opacity(0.6), opacity: 0.7, isGrayStyle: true)
            case .burned, .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#F87171"))
            }
        }
    }
    
    private var placeholderText: String {
        switch task.status {
        case .recording:
            return "Recording"
        case .analyzing:
            return task.progressDescription ?? "Analyzing"
        case .archived:
            return ""
        case .burned:
            return "Burned"
        case .failed:
            return "Analysis Failed"
        }
    }
    
    private var placeholderTextColor: Color {
        switch task.status {
        case .recording:
            return Color(hex: "#60A5FA")
        case .analyzing:
            return Color(hex: "#FBBF24")
        case .archived:
            return Color.white.opacity(0.6)
        case .burned, .failed:
            return Color(hex: "#F87171")
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
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: task.startTime)
    }
    
    private func accessibleImageURL(_ url: String) -> String {
        if url.contains("/api/v1/images/") || url.hasPrefix("http") {
            return url
        }
        // baseURL 已含 /api/v1，故图片 URL = {base}/images/{id}/0
        let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        return "\(base)/images/\(task.id)/0"
    }
}

// MARK: - ScrollingSummaryView
/// 由下至上循环滚动的对话总结，展示全部内容，直到图片生成后替换
struct ScrollingSummaryView: View {
    let text: String
    @State private var offset: CGFloat = 0
    @State private var scrollTask: Task<Void, Never>?
    
    private let scrollDistance: CGFloat = 1200
    private let scrollDuration: Double = 56
    
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .lineSpacing(8)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: offset)
            .onAppear {
                startLoopingScroll()
            }
            .onDisappear {
                scrollTask?.cancel()
            }
    }
    
    private func startLoopingScroll() {
        withAnimation(.linear(duration: scrollDuration)) {
            offset = -scrollDistance
        }
        scrollTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(scrollDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                offset = 0
                startLoopingScroll()
            }
        }
    }
}
