//
//  SkillsRadarCardView.swift
//  WorkSurvivalGuide
//
//  技能雷达卡片：Level 1 场景雷达图（无二级）
//  详情页由 SkillsRadarDetailPage 承载：雷达图 + 高光时刻 + 分场景技能表现/推荐
//

import SwiftUI

// MARK: - Radar Card (Level 1 only, used in carousel)

struct SkillsRadarCardView: View {
    @StateObject private var vm = SkillsRadarViewModel.shared
    let startDate: String
    let endDate: String
    let periodLabel: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                )

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("⚡ Skills Radar")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(periodLabel)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

                // Body
                if vm.isLoading {
                    HStack { Spacer(); ProgressView().tint(.white.opacity(0.4)); Spacer() }
                        .frame(height: 216)
                } else if vm.scenes.isEmpty {
                    HStack { Spacer()
                        Text("No skill data this period")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer() }
                    .frame(height: 216)
                } else {
                    VStack(spacing: 8) {
                        RadarChartView(
                            axes: vm.scenes.map {
                                RadarAxis(
                                    id: $0.scene_id,
                                    label: $0.scene_emoji + "\n" + $0.scene_label,
                                    value: $0.normalizedValue,
                                    dotColor: Color(hex: "#45B7D1")
                                )
                            },
                            fillColor: Color(hex: "#45B7D1"),
                            onTapAxisIndex: nil
                        )
                        .frame(height: 170)

                        // Legend row
                        HStack(spacing: 0) {
                            ForEach(vm.scenes.prefix(5)) { scene in
                                VStack(spacing: 2) {
                                    Text(scene.scene_emoji).font(.system(size: 13))
                                    Text("\(scene.session_count)x")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .task {
            await vm.load(startDate: startDate, endDate: endDate)
        }
    }
}

// MARK: - Detail Page (opened from sheet — radar + highlights + insight)

struct SkillsRadarDetailPage: View {
    @StateObject private var vm = SkillsRadarViewModel.shared
    @StateObject private var insightVM = RadarInsightViewModel()
    let startDate: String
    let endDate: String
    let periodLabel: String

    private var totalSessions: Int {
        vm.scenes.reduce(0) { $0 + $1.session_count }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if vm.isLoading {
                ProgressView().tint(.white.opacity(0.5))
            } else if vm.scenes.isEmpty {
                Text("No skill data this period")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {

                            // ── Radar Chart + [Insight] button ────────────
                            ZStack(alignment: .topTrailing) {
                                RadarChartView(
                                    axes: vm.scenes.map {
                                        RadarAxis(
                                            id: $0.scene_id,
                                            label: $0.scene_emoji + "\n" + $0.scene_label,
                                            value: $0.normalizedValue,
                                            dotColor: Color(hex: "#45B7D1")
                                        )
                                    },
                                    fillColor: Color(hex: "#45B7D1"),
                                    onTapAxisIndex: nil
                                )
                                .frame(height: 220)

                                // Insight button — visible when idle or complete
                                if insightVM.state == .idle || insightVM.state == .complete {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.4)) {
                                            proxy.scrollTo("insightAnchor", anchor: .top)
                                        }
                                        if insightVM.state == .idle {
                                            insightVM.generate(
                                                startDate: startDate,
                                                endDate: endDate,
                                                totalSessions: totalSessions
                                            )
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 10, weight: .semibold))
                                            Text("Insight")
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundColor(Color(hex: "#45B7D1"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(Color(hex: "#45B7D1").opacity(0.12))
                                                .overlay(Capsule().stroke(Color(hex: "#45B7D1").opacity(0.35), lineWidth: 0.8))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.top, 8)
                                    .padding(.trailing, 4)
                                }
                            }
                            .padding(.horizontal, 20)

                            // ── 高光时刻 ──────────────────────────────────
                            if !vm.highlights.isEmpty {
                                RadarSectionHeader(title: "近期高光时刻")
                                VStack(spacing: 10) {
                                    ForEach(vm.highlights) { h in
                                        RadarHighlightCard(highlight: h)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            // ── Insight 锚点 + 内容 ────────────────────────
                            Color.clear.frame(height: 1).id("insightAnchor")

                            switch insightVM.state {
                            case .idle:
                                EmptyView()

                            case .loading:
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ProgressView().tint(Color(hex: "#45B7D1"))
                                        Text("Generating insights...")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(.white.opacity(0.35))
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 32)

                            case .streaming, .complete:
                                ForEach(insightVM.scenes) { scene in
                                    SceneInsightBlock(
                                        scene: scene,
                                        isStreaming: insightVM.streamingSceneId == scene.sceneId
                                    )
                                }

                            case .tooFew:
                                Text("Not enough recordings yet. Come back after a few more conversations to unlock your Insight.")
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 24)
                                    .frame(maxWidth: .infinity)

                            case .error(let msg):
                                Text(msg)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color(hex: "#F87171").opacity(0.8))
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 48)
                    }
                }
            }
        }
        .task(id: startDate + endDate) {
            insightVM.resetAndCheckCache(startDate: startDate, endDate: endDate, totalSessions: 0)
            await vm.load(startDate: startDate, endDate: endDate)
            insightVM.resetAndCheckCache(
                startDate: startDate,
                endDate: endDate,
                totalSessions: totalSessions
            )
        }
    }
}

// MARK: - Scene Insight Block (streaming scene card)

private struct SceneInsightBlock: View {
    let scene: SceneInsightResult
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Scene header
            HStack(spacing: 8) {
                Text(scene.sceneEmoji).font(.system(size: 16))
                Text(scene.sceneLabel)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(scene.sessionCount) 次录音")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)

            // AI Insight text (streaming)
            if !scene.insightText.isEmpty || isStreaming {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#45B7D1").opacity(0.7))
                        .padding(.top, 2)
                    Text(scene.insightText + (isStreaming ? "▋" : ""))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(4)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "#45B7D1").opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(hex: "#45B7D1").opacity(0.15), lineWidth: 0.6)
                )
                .padding(.horizontal, 16)
            }

            // Skills + Recs — 流式完成后才显示
            if !isStreaming {
                let activeSkills = scene.skills.filter { $0.hit_count > 0 }
                if !activeSkills.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("技能表现")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .padding(.horizontal, 16)
                        VStack(spacing: 5) {
                            ForEach(activeSkills) { skill in
                                SkillRowCard(skill: skill)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                if !scene.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("推荐添加")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .textCase(.uppercase)
                            .tracking(0.6)
                            .padding(.horizontal, 16)
                        VStack(spacing: 5) {
                            ForEach(scene.recommendations) { rec in
                                RecommendationRow(rec: rec, onAdded: {})
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.07))
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Section Header

private struct RadarSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
    }
}

// MARK: - Highlight Card (moment-style row)

struct RadarHighlightCard: View {
    let highlight: RadarHighlight

    var body: some View {
        HStack(spacing: 12) {
            // Cover image (56×56, same as WeeklySessionRow)
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.18))
                if let url = highlight.cover_image_url, !url.isEmpty {
                    ImageLoaderView(
                        imageUrl: url,
                        imageBase64: nil,
                        placeholder: "",
                        contentMode: .fill
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text(highlight.scene_emoji)
                        .font(.system(size: 22))
                }
            }
            .frame(width: 56, height: 56)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.session_title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                // Skills hit
                HStack(spacing: 4) {
                    ForEach(highlight.skill_labels.prefix(3), id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "#34D399"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#34D399").opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(highlight.session_date)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                    Text("·")
                        .foregroundColor(.white.opacity(0.2))
                    Text(highlight.scene_emoji + " " + highlight.scene_label)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }
}

// MARK: - Per-Scene Assessment Section

private struct SceneAssessmentSection: View {
    let scene: RadarScene
    @StateObject private var vm = SkillsRadarViewModel.shared

    private var activeSkills: [RadarSkill] { scene.skills.filter { $0.hit_count > 0 } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Scene header
            HStack(spacing: 8) {
                Text(scene.scene_emoji)
                    .font(.system(size: 16))
                Text(scene.scene_label)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                Text("\(scene.session_count) 次录音")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.horizontal, 16)

            // 技能表现
            if !activeSkills.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("技能表现")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .padding(.horizontal, 16)
                    VStack(spacing: 5) {
                        ForEach(activeSkills) { skill in
                            SkillRowCard(skill: skill)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // 推荐添加
            if !scene.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("推荐添加")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .padding(.horizontal, 16)
                    VStack(spacing: 5) {
                        ForEach(scene.recommendations) { rec in
                            RecommendationRow(rec: rec, onAdded: {
                                vm.markRecommendationAdded(skillId: rec.skill_id)
                            })
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Divider()
                .background(Color.white.opacity(0.07))
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - Skill Row (active)

private struct SkillRowCard: View {
    let skill: RadarSkill

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.skill_label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(i < skill.pipCount ? Color(hex: "#45B7D1") : Color.white.opacity(0.1))
                            .frame(width: 5, height: 5)
                    }
                    if let level = skill.level {
                        Text(level)
                            .font(.system(size: 9, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.leading, 2)
                    }
                }
            }
            Spacer()
            SparklineView(data: skill.sparkline)
                .frame(width: 48, height: 18)
            HStack(spacing: 2) {
                Text(skill.trendSymbol).font(.system(size: 10, weight: .bold))
                Text(skill.trendLabel).font(.system(size: 9, design: .rounded))
            }
            .foregroundColor(skill.trendColor)
            .frame(width: 52, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Recommendation Row

private struct RecommendationRow: View {
    let rec: RadarRecommendation
    let onAdded: () -> Void
    @State private var added = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rec.skill_label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                Text(rec.reason)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
            }
            Spacer()
            Button(action: { guard !added else { return }; added = true; onAdded() }) {
                HStack(spacing: 3) {
                    Image(systemName: added ? "checkmark" : "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text(added ? "已添加" : "添加")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundColor(added ? Color(hex: "#34D399") : Color(hex: "#45B7D1"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(
                            added ? Color(hex: "#34D399").opacity(0.5) : Color(hex: "#45B7D1").opacity(0.5),
                            lineWidth: 0.8
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

// MARK: - Sparkline

private struct SparklineView: View {
    let data: [Int]

    var body: some View {
        Canvas { ctx, size in
            guard !data.isEmpty else { return }
            let n = data.count
            let step = size.width / CGFloat(max(n - 1, 1))
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: size.height / 2))
            baseline.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            ctx.stroke(baseline, with: .color(.white.opacity(0.07)), lineWidth: 0.8)
            var linePath = Path()
            var started = false
            for (i, val) in data.enumerated() {
                let x = CGFloat(i) * step
                let y = val == 1 ? size.height * 0.12 : size.height * 0.88
                if !started { linePath.move(to: CGPoint(x: x, y: y)); started = true }
                else { linePath.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(linePath, with: .color(.white.opacity(0.2)), lineWidth: 1)
            for (i, val) in data.enumerated() {
                let x = CGFloat(i) * step
                let y = val == 1 ? size.height * 0.12 : size.height * 0.88
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)),
                         with: .color(val == 1 ? Color(hex: "#34D399") : Color.white.opacity(0.12)))
            }
        }
    }
}

// MARK: - Radar Chart

struct RadarAxis: Identifiable {
    let id: String
    let label: String
    let value: Double
    let dotColor: Color
}

struct RadarChartView: View {
    let axes: [RadarAxis]
    let fillColor: Color
    let onTapAxisIndex: ((Int) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2 - 28
            let n = axes.count
            guard n >= 2 else {
                return AnyView(
                    Text(axes.first?.label ?? "")
                        .foregroundColor(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                )
            }
            return AnyView(
                ZStack {
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        let r = min(sz.width, sz.height) / 2 - 28
                        for ring in [0.33, 0.66, 1.0] as [Double] {
                            var p = Path()
                            for i in 0..<n {
                                let pt = radarPoint(c: c, r: r * ring, i: i, n: n)
                                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                            }
                            p.closeSubpath()
                            ctx.stroke(p, with: .color(.white.opacity(ring == 1.0 ? 0.1 : 0.06)), lineWidth: 0.6)
                        }
                        for i in 0..<n {
                            var ap = Path()
                            ap.move(to: c)
                            ap.addLine(to: radarPoint(c: c, r: r, i: i, n: n))
                            ctx.stroke(ap, with: .color(.white.opacity(0.08)), lineWidth: 0.6)
                        }
                    }
                    Canvas { ctx, sz in
                        let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
                        let r = min(sz.width, sz.height) / 2 - 28
                        var p = Path()
                        for (i, axis) in axes.enumerated() {
                            let pt = radarPoint(c: c, r: r * CGFloat(axis.value), i: i, n: n)
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                        p.closeSubpath()
                        ctx.fill(p, with: .color(fillColor.opacity(0.22)))
                        ctx.stroke(p, with: .color(fillColor.opacity(0.65)), lineWidth: 1.5)
                    }
                    ForEach(Array(axes.enumerated()), id: \.element.id) { idx, axis in
                        let dotPt = radarPoint(c: center, r: maxR * CGFloat(axis.value), i: idx, n: n)
                        let labelPt = radarPoint(c: center, r: maxR + 18, i: idx, n: n)
                        Circle()
                            .fill(axis.dotColor)
                            .frame(width: 7, height: 7)
                            .position(dotPt)
                        Text(axis.label)
                            .font(.system(size: 8.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 60)
                            .position(labelPt)
                        if onTapAxisIndex != nil {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                                .position(dotPt)
                                .onTapGesture { onTapAxisIndex?(idx) }
                        }
                    }
                }
            )
        }
    }

    private func radarPoint(c: CGPoint, r: CGFloat, i: Int, n: Int) -> CGPoint {
        let angle = -Double.pi / 2 + Double(i) * 2 * Double.pi / Double(n)
        return CGPoint(x: c.x + r * CGFloat(cos(angle)),
                       y: c.y + r * CGFloat(sin(angle)))
    }
}
