//
//  AbilityRadarView.swift
//  WorkSurvivalGuide
//
//  六维能力雷达图卡片：六边形网格 + 数值区域 + 节点 + 点击弹出详情
//

import SwiftUI

// MARK: - ViewModel

@MainActor
class AbilityRadarViewModel: ObservableObject {
    static let shared = AbilityRadarViewModel()

    @Published var abilities: [AbilityScore] = []
    @Published var newBadges: [AbilityBadge] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var lastFetched: Date? = nil

    func load(forceRefresh: Bool = false) {
        let stale = lastFetched.map { Date().timeIntervalSince($0) > 300 } ?? true
        guard forceRefresh || stale else { return }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let data = try await NetworkManager.shared.getAbilityScores()
                // 按展示顺序排列
                let ordered = AbilityScore.displayOrder.compactMap { t in data.abilities.first { $0.type == t } }
                self.abilities = ordered.isEmpty ? data.abilities : ordered
                self.newBadges = data.newBadges
                self.lastFetched = Date()
            } catch {
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }
}

// MARK: - Root Card View

struct AbilityRadarView: View {
    @ObservedObject private var vm = AbilityRadarViewModel.shared
    @State private var selectedAbility: AbilityScore? = nil
    @State private var badgeQueue: [AbilityBadge] = []
    @State private var currentBadge: AbilityBadge? = nil

    var body: some View {
        ZStack {
            // ── 银河背景 ─────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(hex: "#050B1A"), Color(hex: "#0D1B3E")],
                    center: .center, startRadius: 0, endRadius: 240
                ))
                .overlay {
                    Canvas { ctx, size in
                        var seed: UInt64 = 42137
                        func rand() -> Double {
                            seed = seed &* 6364136223846793005 &+ 1442695040888963407
                            return Double(seed >> 33) / Double(UInt32.max)
                        }
                        for _ in 0..<80 {
                            let x  = rand() * Double(size.width)
                            let y  = rand() * Double(size.height)
                            let r  = rand() * 0.6 + 0.4
                            let op = rand() * 0.5 + 0.2
                            let rect = CGRect(x: x-r, y: y-r, width: r*2, height: r*2)
                            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(op)))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("能力雷达")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#00D4FF"))
                    Spacer()
                    if vm.isLoading {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Button { vm.load(forceRefresh: true) } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)

                if vm.abilities.isEmpty && !vm.isLoading {
                    VStack(spacing: 8) {
                        Text("暂无能力数据")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.3))
                        Text("完成第一次对话分析后解锁")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    GeometryReader { geo in
                        RadarChartCanvas(
                            abilities: vm.abilities,
                            size: min(geo.size.width, geo.size.height)
                        ) { ability in
                            selectedAbility = ability
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .frame(height: 190)
                    .padding(.horizontal, 8)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                if let top = vm.abilities.max(by: { $0.score < $1.score }) {
                    HStack(spacing: 6) {
                        Text(top.icon)
                        Text("\(top.name) · \(Int(top.score))分")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#00D4FF").opacity(0.8))
                        Spacer()
                        Text("点击节点查看详情")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.white.opacity(0.2))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#00D4FF").opacity(0.15), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
        .onAppear { vm.load() }
        .onChange(of: vm.newBadges.count) { _ in
            guard !vm.newBadges.isEmpty else { return }
            badgeQueue = vm.newBadges
            if currentBadge == nil {
                currentBadge = badgeQueue.removeFirst()
            }
        }
        .sheet(item: $selectedAbility) { ability in
            AbilityDetailSheet(ability: ability)
        }
        .fullScreenCover(item: $currentBadge) { badge in
            BadgeUnlockView(badge: badge) {
                currentBadge = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if !badgeQueue.isEmpty {
                        currentBadge = badgeQueue.removeFirst()
                    }
                }
            }
        }
    }
}

// MARK: - Radar Canvas (pure Canvas, no state)

private struct RadarChartCanvas: View {
    let abilities: [AbilityScore]
    let size: CGFloat
    let onTap: (AbilityScore) -> Void

    private let layers = 5
    private let cyan = Color(hex: "#00D4FF")

    var body: some View {
        ZStack {
            // 六边形网格
            Canvas { ctx, sz in
                let center = CGPoint(x: sz.width/2, y: sz.height/2)
                let maxR = sz.width * 0.42

                // 5层网格
                for layer in 1...layers {
                    let r = maxR * CGFloat(layer) / CGFloat(layers)
                    var path = Path()
                    for i in 0..<6 {
                        let pt = hexPoint(center: center, radius: r, index: i)
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
                    path.addLine(to: hexPoint(center: center, radius: maxR, index: i))
                    ctx.stroke(path, with: .color(cyan.opacity(0.12)), lineWidth: 0.5)
                }

                // 数值区域（青色渐变填充）
                if abilities.count == 6 {
                    var fillPath = Path()
                    for (i, ab) in abilities.enumerated() {
                        let r = maxR * CGFloat(ab.score / 100)
                        let pt = hexPoint(center: center, radius: r, index: i)
                        if i == 0 { fillPath.move(to: pt) } else { fillPath.addLine(to: pt) }
                    }
                    fillPath.closeSubpath()
                    ctx.fill(fillPath, with: .color(cyan.opacity(0.18)))
                    ctx.stroke(fillPath, with: .color(cyan.opacity(0.55)), lineWidth: 1.5)
                }
            }

            // 节点（可点击）
            let center = CGPoint(x: size/2, y: size/2)
            let maxR = size * 0.42
            ForEach(Array(abilities.enumerated()), id: \.offset) { i, ability in
                let r = maxR * CGFloat(ability.score / 100)
                let pt = hexPoint(center: center, radius: r, index: i)
                let labelPt = hexPoint(center: center, radius: maxR + 18, index: i)

                ZStack {
                    // 节点
                    Button { onTap(ability) } label: {
                        ZStack {
                            Circle()
                                .fill(abilityColor(ability.type).opacity(0.3))
                                .frame(width: nodeSize(ability.score) + 8, height: nodeSize(ability.score) + 8)
                                .blur(radius: 5)
                            Circle()
                                .fill(abilityColor(ability.type))
                                .frame(width: nodeSize(ability.score), height: nodeSize(ability.score))
                            // 4芒星
                            Canvas { ctx, sz in
                                let cx = sz.width/2, cy = sz.height/2
                                let vL: CGFloat = 7, hL: CGFloat = 4
                                var v = Path(); v.move(to: CGPoint(x:cx,y:cy-vL)); v.addLine(to: CGPoint(x:cx,y:cy+vL))
                                var h = Path(); h.move(to: CGPoint(x:cx-hL,y:cy)); h.addLine(to: CGPoint(x:cx+hL,y:cy))
                                ctx.stroke(v, with: .color(.white.opacity(0.9)), lineWidth: 0.8)
                                ctx.stroke(h, with: .color(.white.opacity(0.6)), lineWidth: 0.8)
                            }
                            .frame(width: nodeSize(ability.score)+6, height: nodeSize(ability.score)+6)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(pt)

                    // 标签（能力图标+名称）
                    VStack(spacing: 1) {
                        Text(ability.icon)
                            .font(.system(size: 12))
                        Text(ability.name)
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .position(labelPt)
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func hexPoint(center: CGPoint, radius: CGFloat, index: Int) -> CGPoint {
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

// MARK: - 勋章解锁全屏动画

struct BadgeUnlockView: View {
    let badge: AbilityBadge
    let onDismiss: () -> Void

    @State private var rippleScale: CGFloat = 0.01
    @State private var rippleOpacity: Double = 0.9
    @State private var badgeScale: CGFloat = 0.1
    @State private var badgeRotation: Double = -180.0
    @State private var badgeBlur: Double = 20.0
    @State private var contentOpacity: Double = 0

    private let cyan = Color(hex: "#00D4FF")

    var body: some View {
        ZStack {
            // 深空背景
            Color(hex: "#050B1A")
                .ignoresSafeArea()

            // AirDrop 涟漪（3圈）
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(
                        cyan.opacity(rippleOpacity / Double(i + 1)),
                        lineWidth: 1.5 - CGFloat(i) * 0.3
                    )
                    .frame(width: 180 + CGFloat(i * 70),
                           height: 180 + CGFloat(i * 70))
                    .scaleEffect(rippleScale)
            }

            VStack(spacing: 24) {
                Spacer()

                // 勋章图标
                ZStack {
                    Circle()
                        .fill(cyan.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                    Circle()
                        .stroke(cyan.opacity(0.25), lineWidth: 1)
                        .frame(width: 120, height: 120)
                    Text(badge.icon)
                        .font(.system(size: 64))
                        .blur(radius: badgeBlur)
                        .rotationEffect(.degrees(badgeRotation))
                        .scaleEffect(badgeScale)
                }

                // 文字
                VStack(spacing: 10) {
                    Text("🎖️ 解锁成就")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(cyan.opacity(0.7))

                    Text(badge.name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text(badge.desc)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(contentOpacity)

                Spacer()

                // 按钮
                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        badgeScale = 0.8
                        contentOpacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onDismiss() }
                } label: {
                    Text("精彩！")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 160, height: 48)
                        .background(
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [cyan.opacity(0.35), cyan.opacity(0.15)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .overlay(Capsule().stroke(cyan.opacity(0.4), lineWidth: 1))
                        )
                }
                .opacity(contentOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            // Haptic 三连
            [0.05, 0.25, 0.45].forEach { delay in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                }
            }
            // 涟漪扩散
            withAnimation(.easeOut(duration: 0.9)) {
                rippleScale = 1.3
                rippleOpacity = 0
            }
            // 勋章入场：模糊→清晰 + 旋转
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.15)) {
                badgeScale = 1.0
                badgeRotation = 0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                badgeBlur = 0
            }
            // 文字淡入
            withAnimation(.easeIn(duration: 0.35).delay(0.5)) {
                contentOpacity = 1
            }
        }
        .preferredColorScheme(.dark)
    }
}
