//
//  StarMapDetailView.swift
//  WorkSurvivalGuide
//
//  Detail page: 六维能力雷达图 + 能力详情卡片 + 大事件跳转
//

import SwiftUI
import Charts
import UIKit

struct StarMapDetailView: View {
    let categoryId: String
    let label: String
    let accent: Color
    let skills: [SkillCatalogItem]
    let tasks: [TaskItem]
    var initialAbilityType: String? = nil   // 进入时预选节点

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var abilityVM = AbilityRadarViewModel.shared

    @State private var selectedAbilityType: String? = nil
    @State private var selectedTask: TaskItem? = nil
    @State private var timelineFilter: TimelineFilter = .month

    enum TimelineFilter: String, CaseIterable {
        case week  = "本周"
        case month = "本月"
        case all   = "全部"
    }

    // MARK: - 计算属性

    private var pageTitle: String {
        switch categoryId {
        case "workplace": return "职场星域"
        case "family":    return "家庭星域"
        default:          return "成长星域"
        }
    }

    private var selectedAbility: AbilityScore? {
        guard !abilityVM.abilities.isEmpty else { return nil }
        if let type = selectedAbilityType,
           let found = abilityVM.abilities.first(where: { $0.type == type }) {
            return found
        }
        return abilityVM.abilities.max(by: { $0.score < $1.score })
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "#050B1A").ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        radarSection
                            .padding(.top, 4)

                        if let ability = selectedAbility {
                            abilityDetailSection(ability)
                                .id(ability.type)
                                .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                                .padding(.top, 16)
                                .padding(.horizontal, 16)
                        } else if abilityVM.isLoading {
                            ProgressView()
                                .tint(Color(hex: "#00D4FF"))
                                .padding(.top, 60)
                        } else if !abilityVM.abilities.isEmpty {
                            EmptyView()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "moon.stars")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.15))
                                Text("暂无能力数据")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("完成第一次对话分析后解锁")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                            .padding(.top, 60)
                        }

                        Spacer(minLength: 48)
                    }
                    .animation(.easeInOut(duration: 0.3), value: selectedAbilityType)
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .onAppear {
            abilityVM.load(forceRefresh: true)
            // 预选节点（数据加载后 selectedAbility 计算属性会自动使用它）
            if let type = initialAbilityType {
                selectedAbilityType = type
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.10)))
            }

            Text(pageTitle)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            if abilityVM.isLoading {
                ProgressView()
                    .tint(Color(hex: "#00D4FF"))
                    .scaleEffect(0.8)
            } else {
                Button { abilityVM.load(forceRefresh: true) } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
    }

    // MARK: - Radar Section

    private var radarSection: some View {
        ZStack(alignment: .bottom) {
            // 深空背景
            Rectangle()
                .fill(RadialGradient(
                    colors: [Color(hex: "#050B1A"), Color(hex: "#0D1B3E")],
                    center: .center, startRadius: 0, endRadius: 300
                ))
                .overlay {
                    Canvas { ctx, size in
                        var seed: UInt64 = 73641
                        func rand() -> Double {
                            seed = seed &* 6364136223846793005 &+ 1442695040888963407
                            return Double(seed >> 33) / Double(UInt32.max)
                        }
                        for _ in 0..<150 {
                            let x  = rand() * Double(size.width)
                            let y  = rand() * Double(size.height)
                            let r  = rand() * 0.8 + 0.3
                            let op = rand() * 0.5 + 0.2
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                with: .color(.white.opacity(op))
                            )
                        }
                    }
                }

            VStack(spacing: 0) {
                // 标题行
                HStack {
                    Text("六维能力雷达")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#00D4FF"))
                    Spacer()
                    Text("点击节点查看详情")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 4)

                // 雷达图
                GeometryReader { geo in
                    let sz = min(geo.size.width, geo.size.height)
                    DetailRadarCanvas(
                        abilities: abilityVM.abilities,
                        size: sz,
                        selectedType: selectedAbilityType
                    ) { type in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedAbilityType = type
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: 240)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)
            }

            // 底部分隔线
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
        }
        .frame(height: 300)
    }

    // MARK: - Ability Detail Section

    @ViewBuilder
    private func abilityDetailSection(_ ability: AbilityScore) -> some View {
        let color = abilityAccentColor(ability.type)

        VStack(alignment: .leading, spacing: 20) {
            abilityHeaderCard(ability, accent: color)

            if !ability.relatedSkills.isEmpty {
                relatedSkillsSection(ability, accent: color)
            }

            if !ability.recentEvents.isEmpty {
                eventsSection(ability, accent: color)
            }

            growthChartSection(ability, accent: color)
        }
    }

    // MARK: - Ability Header Card

    private func abilityHeaderCard(_ ability: AbilityScore, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // 名称 + 等级
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ability.icon)
                    .font(.system(size: 26))
                Text(ability.name)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(ability.level)\(ability.levelEmoji)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(accent.opacity(0.15)))
            }

            // 分数 + 月增长
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(ability.score))")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(accent)
                Text("分")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 2)
                Spacer()
                if ability.monthlyGrowth > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 11, weight: .semibold))
                        Text("本月+\(ability.monthlyGrowth)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(hex: "#34D399"))
                }
            }

            // 进度条
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [accent.opacity(0.6), accent],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(ability.score / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#0D1B3E").opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(accent.opacity(0.25), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Related Skills Section

    private func relatedSkillsSection(_ ability: AbilityScore, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关联技能")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(ability.relatedSkills.enumerated()), id: \.offset) { _, skill in
                        Text(skill)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accent.opacity(0.12)))
                            .overlay(Capsule().stroke(accent.opacity(0.3), lineWidth: 0.8))
                    }
                }
            }
        }
    }

    // MARK: - Events Section

    private func eventsSection(_ ability: AbilityScore, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("近期大事件")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("全部")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(accent.opacity(0.8))
            }

            VStack(spacing: 10) {
                ForEach(ability.recentEvents) { event in
                    abilityEventCard(event, accent: accent)
                }
            }
        }
    }

    private func abilityEventCard(_ event: AbilityEvent, accent: Color) -> some View {
        Button {
            selectedTask = TaskItem(
                id: event.sessionId,
                title: event.title,
                startTime: Date(),
                endTime: nil,
                duration: 0,
                tags: [],
                status: .archived,
                emotionScore: nil,
                speakerCount: nil,
                summary: event.summary,
                coverImageUrl: nil,
                progressDescription: nil
            )
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // 左侧：outcome 图标 + 标签
                let oColor = outcomeColor(event.outcome)
                VStack(spacing: 3) {
                    Image(systemName: outcomeIcon(event.outcome))
                        .font(.system(size: 20))
                        .foregroundColor(oColor)
                    Text(outcomeLabel(event.outcome))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(oColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(oColor.opacity(0.15)))
                }
                .frame(width: 42)

                // 右侧：内容
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Text(event.date)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(accent.opacity(0.8))
                    }
                    // 能力标签 + 技能标签
                    if let aName = event.abilityName, !aName.isEmpty,
                       let aType = event.abilityType {
                        HStack(spacing: 6) {
                            let aColor = abilityTagColor(aType)
                            Text(abilityEmojiFor(aType) + " " + aName)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(aColor)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(aColor.opacity(0.15)))
                            if let sName = event.skillName, !sName.isEmpty {
                                Text(sName)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.white.opacity(0.06)))
                            }
                        }
                    }
                    if !event.summary.isEmpty {
                        Text(event.summary)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Growth Chart Section

    private func growthChartSection(_ ability: AbilityScore, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题 + 筛选器
            HStack {
                Text("成长时间轴")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                // 筛选 Segment
                HStack(spacing: 0) {
                    ForEach(TimelineFilter.allCases, id: \.self) { filter in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { timelineFilter = filter }
                        } label: {
                            Text(filter.rawValue)
                                .font(.system(size: 11, weight: timelineFilter == filter ? .semibold : .regular,
                                             design: .rounded))
                                .foregroundColor(timelineFilter == filter ? .white : .white.opacity(0.4))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(timelineFilter == filter ? accent.opacity(0.25) : Color.clear)
                                )
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.05))
                )
            }

            // 趋势折线图（4周数据）
            let allLabels = ["-3周", "-2周", "-1周", "本周"]
            let dataPoints: [(String, Double)] = {
                switch timelineFilter {
                case .week:  return Array(zip(allLabels, ability.growthTrend).suffix(1))
                case .month: return Array(zip(allLabels, ability.growthTrend))
                case .all:   return Array(zip(allLabels, ability.growthTrend))
                }
            }()

            Chart {
                ForEach(dataPoints, id: \.0) { label, value in
                    LineMark(
                        x: .value("时段", label),
                        y: .value("分数", value)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [accent.opacity(0.6), accent],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("时段", label),
                        y: .value("分数", value)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [accent.opacity(0.22), accent.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("时段", label),
                        y: .value("分数", value)
                    )
                    .foregroundStyle(.white)
                    .symbolSize(25)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        .foregroundStyle(Color.white.opacity(0.07))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            .frame(height: 140)
            .padding(.vertical, 4)

            // 大事件时间轴（根据筛选显示）
            let eventsToShow: [AbilityEvent] = {
                switch timelineFilter {
                case .week:  return ability.recentEvents.filter { $0.date >= thisWeekPrefix() }
                case .month: return ability.recentEvents
                case .all:   return ability.recentEvents
                }
            }()

            if !eventsToShow.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(eventsToShow.enumerated()), id: \.element.id) { idx, event in
                        HStack(alignment: .top, spacing: 12) {
                            // 时间轴竖线 + 节点
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 4)
                                if idx < eventsToShow.count - 1 {
                                    Rectangle()
                                        .fill(accent.opacity(0.2))
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 8)

                            // 内容
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(event.date)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(accent.opacity(0.8))
                                    Spacer()
                                    let oColor = outcomeColor(event.outcome)
                                    Text(outcomeLabel(event.outcome))
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(oColor)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(oColor.opacity(0.15)))
                                }
                                Text(event.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                if let aName = event.abilityName, !aName.isEmpty,
                                   let aType = event.abilityType {
                                    let aColor = abilityTagColor(aType)
                                    HStack(spacing: 5) {
                                        Text(abilityEmojiFor(aType) + " " + aName)
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundColor(aColor)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1.5)
                                            .background(Capsule().fill(aColor.opacity(0.15)))
                                        if let sName = event.skillName, !sName.isEmpty {
                                            Text(sName)
                                                .font(.system(size: 10, design: .rounded))
                                                .foregroundColor(.white.opacity(0.35))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 1.5)
                                                .background(Capsule().fill(Color.white.opacity(0.06)))
                                        }
                                    }
                                }
                                if !event.summary.isEmpty {
                                    Text(event.summary)
                                        .font(.system(size: 11, design: .rounded))
                                        .foregroundColor(.white.opacity(0.45))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.bottom, idx < eventsToShow.count - 1 ? 14 : 0)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.bottom, 24)
    }

    private func thisWeekPrefix() -> String {
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now) ?? now
        let fmt = DateFormatter()
        fmt.dateFormat = "MM.dd"
        // 日期字符串 >= 7天前的日期字符串（简单字符串比较，年份相同时有效）
        return fmt.string(from: weekAgo)
    }

    // MARK: - Helpers

    private func abilityAccentColor(_ type: String) -> Color {
        switch type {
        case "influence": return Color(hex: "#FFD700")
        case "control":   return Color(hex: "#45B7D1")
        case "insight":   return Color(hex: "#A78BFA")
        case "empathy":   return Color(hex: "#F472B6")
        case "defense":   return Color(hex: "#34D399")
        case "execution": return Color(hex: "#FB923C")
        default:          return Color(hex: "#00D4FF")
        }
    }

    private func outcomeIcon(_ outcome: String?) -> String {
        switch outcome {
        case "breakthrough": return "arrow.up.circle.fill"
        case "setback":      return "exclamationmark.circle.fill"
        default:             return "arrow.up.right.circle.fill"
        }
    }

    private func outcomeColor(_ outcome: String?) -> Color {
        switch outcome {
        case "breakthrough": return Color(hex: "#34D399")
        case "setback":      return Color(hex: "#FBBF24")
        default:             return Color(hex: "#60A5FA")
        }
    }

    private func outcomeLabel(_ outcome: String?) -> String {
        switch outcome {
        case "breakthrough": return "⬆ 突破"
        case "setback":      return "⚠ 复盘"
        default:             return "↗ 实践"
        }
    }

    private func abilityTagColor(_ type: String) -> Color {
        switch type {
        case "influence": return Color(hex: "#FFD700")
        case "control":   return Color(hex: "#45B7D1")
        case "insight":   return Color(hex: "#A78BFA")
        case "empathy":   return Color(hex: "#F472B6")
        case "defense":   return Color(hex: "#34D399")
        case "execution": return Color(hex: "#FB923C")
        default:          return Color(hex: "#45B7D1")
        }
    }

    private func abilityEmojiFor(_ type: String) -> String {
        switch type {
        case "influence": return "💞"
        case "control":   return "🎯"
        case "insight":   return "🔭"
        case "empathy":   return "⚡"
        case "defense":   return "🛡️"
        case "execution": return "🚀"
        default:          return "✨"
        }
    }
}

// MARK: - Detail Radar Canvas（支持选中节点高亮）

private struct DetailRadarCanvas: View {
    let abilities: [AbilityScore]
    let size: CGFloat
    let selectedType: String?
    let onTap: (String) -> Void

    private let layers = 5
    private let cyan = Color(hex: "#00D4FF")

    var body: some View {
        ZStack {
            // 六边形网格 + 数值区域（Canvas）
            Canvas { ctx, sz in
                let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
                let maxR = sz.width * 0.38

                // 5层网格线
                for layer in 1...layers {
                    let r = maxR * CGFloat(layer) / CGFloat(layers)
                    var path = Path()
                    for i in 0..<6 {
                        let pt = hexPt(center: center, radius: r, index: i)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                    let opacity = 0.05 + 0.04 * Double(layer)
                    ctx.stroke(path, with: .color(cyan.opacity(opacity)), lineWidth: 0.6)
                }

                // 6条轴线
                for i in 0..<6 {
                    var path = Path()
                    path.move(to: center)
                    path.addLine(to: hexPt(center: center, radius: maxR, index: i))
                    ctx.stroke(path, with: .color(cyan.opacity(0.12)), lineWidth: 0.5)
                }

                // 数值填充区域
                if abilities.count == 6 {
                    var fillPath = Path()
                    for (i, ab) in abilities.enumerated() {
                        let r = maxR * CGFloat(ab.score / 100)
                        let pt = hexPt(center: center, radius: r, index: i)
                        if i == 0 { fillPath.move(to: pt) } else { fillPath.addLine(to: pt) }
                    }
                    fillPath.closeSubpath()
                    ctx.fill(fillPath, with: .color(cyan.opacity(0.18)))
                    ctx.stroke(fillPath, with: .color(cyan.opacity(0.55)), lineWidth: 1.5)
                }
            }

            // 节点（SwiftUI层，可点击）
            let center = CGPoint(x: size / 2, y: size / 2)
            let maxR   = size * 0.38

            ForEach(Array(abilities.enumerated()), id: \.offset) { i, ability in
                let r         = maxR * CGFloat(ability.score / 100)
                let pt        = hexPt(center: center, radius: r, index: i)
                let labelPt   = hexPt(center: center, radius: maxR + 22, index: i)
                let isSelected = selectedType == ability.type
                let nodeColor  = abilityColor(ability.type)
                let ns         = nodeSize(ability.score)

                ZStack {
                    // 可点击节点
                    Button { onTap(ability.type) } label: {
                        ZStack {
                            // 光晕
                            Circle()
                                .fill(nodeColor.opacity(isSelected ? 0.55 : 0.25))
                                .frame(width: ns + (isSelected ? 16 : 8),
                                       height: ns + (isSelected ? 16 : 8))
                                .blur(radius: isSelected ? 9 : 4)

                            // 节点圆
                            Circle()
                                .fill(nodeColor)
                                .frame(width: ns, height: ns)

                            // 4芒星
                            Canvas { ctx, sz in
                                let cx = sz.width / 2, cy = sz.height / 2
                                let vL: CGFloat = 7, hL: CGFloat = 4
                                var v = Path()
                                v.move(to: CGPoint(x: cx, y: cy - vL))
                                v.addLine(to: CGPoint(x: cx, y: cy + vL))
                                var h = Path()
                                h.move(to: CGPoint(x: cx - hL, y: cy))
                                h.addLine(to: CGPoint(x: cx + hL, y: cy))
                                ctx.stroke(v, with: .color(.white.opacity(0.9)), lineWidth: 0.8)
                                ctx.stroke(h, with: .color(.white.opacity(0.6)), lineWidth: 0.8)
                            }
                            .frame(width: ns + 6, height: ns + 6)
                        }
                        .scaleEffect(isSelected ? 1.35 : 1.0)
                        .shadow(color: nodeColor.opacity(isSelected ? 0.95 : 0.3),
                                radius: isSelected ? 14 : 4)
                        .animation(.easeInOut(duration: 0.25), value: isSelected)
                    }
                    .buttonStyle(.plain)
                    .position(pt)

                    // 标签
                    VStack(spacing: 1) {
                        Text(ability.icon)
                            .font(.system(size: 12))
                        Text(ability.name)
                            .font(.system(size: isSelected ? 9 : 8,
                                         weight: isSelected ? .bold : .semibold,
                                         design: .rounded))
                            .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .position(labelPt)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.25), value: isSelected)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func hexPt(center: CGPoint, radius: CGFloat, index: Int) -> CGPoint {
        let angle = (CGFloat(index) * 60 - 90) * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle),
                       y: center.y + radius * sin(angle))
    }

    private func nodeSize(_ score: Double) -> CGFloat {
        CGFloat(score / 100) * 12 + 8
    }

    private func abilityColor(_ type: String) -> Color {
        switch type {
        case "influence": return Color(hex: "#FFD700")
        case "control":   return Color(hex: "#45B7D1")
        case "insight":   return Color(hex: "#A78BFA")
        case "empathy":   return Color(hex: "#F472B6")
        case "defense":   return Color(hex: "#34D399")
        case "execution": return Color(hex: "#FB923C")
        default:          return Color(hex: "#00D4FF")
        }
    }
}
