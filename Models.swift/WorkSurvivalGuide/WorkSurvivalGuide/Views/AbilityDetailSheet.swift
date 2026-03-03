//
//  AbilityDetailSheet.swift
//  WorkSurvivalGuide
//
//  能力详情底部弹窗：分数 + 关联技能 + 近期大事件 + 成长曲线
//

import SwiftUI
import Charts

struct AbilityDetailSheet: View {
    let ability: AbilityScore
    @Environment(\.dismiss) private var dismiss

    // 用于跳转 TaskDetailView
    @State private var selectedSessionItem: TaskItem? = nil
    @State private var navigateToDetail = false

    private var accentColor: Color {
        switch ability.type {
        case "influence": return Color(hex: "#FFD700")
        case "control":   return Color(hex: "#45B7D1")
        case "insight":   return Color(hex: "#A78BFA")
        case "empathy":   return Color(hex: "#F472B6")
        case "defense":   return Color(hex: "#34D399")
        case "execution": return Color(hex: "#FB923C")
        default:          return Color(hex: "#45B7D1")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0F1E").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // ── 顶部：能力名 + 等级 + 分数进度条 ──────────────
                        headerSection

                        // ── 关联技能标签 ────────────────────────────────
                        if !ability.relatedSkills.isEmpty {
                            relatedSkillsSection
                        }

                        // ── 近期大事件 ──────────────────────────────────
                        if !ability.recentEvents.isEmpty {
                            eventsSection
                        }

                        // ── 成长曲线 ────────────────────────────────────
                        growthChartSection

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }

                // 跳转 TaskDetailView
                NavigationLink(
                    destination: Group {
                        if let item = selectedSessionItem {
                            TaskDetailView(task: item)
                        }
                    },
                    isActive: $navigateToDetail
                ) { EmptyView() }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ability.icon)
                    .font(.system(size: 28))
                Text(ability.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(ability.level)\(ability.levelEmoji)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(accentColor.opacity(0.15)))
            }

            // 分数 + 月增长
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(ability.score))")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(accentColor)
                Text("分")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 4)
                Spacer()
                if ability.monthlyGrowth > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .semibold))
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
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [accentColor.opacity(0.6), accentColor],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(ability.score / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Related Skills

    private var relatedSkillsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("关联技能")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(ability.relatedSkills.enumerated()), id: \.offset) { _, skill in
                        Text(skill)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(accentColor.opacity(0.12)))
                            .overlay(Capsule().stroke(accentColor.opacity(0.3), lineWidth: 0.8))
                    }
                }
            }
        }
    }

    // MARK: - Events

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("近期大事件")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("全部")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(accentColor.opacity(0.8))
            }

            VStack(spacing: 10) {
                ForEach(ability.recentEvents) { event in
                    eventCard(event)
                }
            }
        }
    }

    private func eventCard(_ event: AbilityEvent) -> some View {
        Button {
            // 构造最小 TaskItem 并跳转
            selectedSessionItem = makeTaskItem(from: event)
            navigateToDetail = true
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
                    // 标题 + 日期
                    HStack {
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Text(event.date)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(accentColor.opacity(0.8))
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
                    // 摘要
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

    // MARK: - Growth Chart

    private var growthChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("成长曲线")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))

            let labels = ["-3周", "-2周", "-1周", "本周"]
            let dataPoints = zip(labels, ability.growthTrend).map { ($0.0, $0.1) }

            Chart {
                ForEach(dataPoints, id: \.0) { label, value in
                    LineMark(
                        x: .value("时段", label),
                        y: .value("分数", value)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [accentColor.opacity(0.6), accentColor],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("时段", label),
                        y: .value("分数", value)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [accentColor.opacity(0.25), accentColor.opacity(0.02)],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("时段", label),
                        y: .value("分数", value)
                    )
                    .foregroundStyle(accentColor)
                    .symbolSize(30)
                }
            }
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: .automatic) { val in
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3]))
                        .foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel()
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
            }
            .frame(height: 140)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Helpers

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

    private func makeTaskItem(from event: AbilityEvent) -> TaskItem {
        TaskItem(
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
    }
}
