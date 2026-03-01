//
//  SkillConstellationView.swift
//  WorkSurvivalGuide
//
//  可滑动星图卡片：3个域专属雷达（职场/家庭/个人）
//  点击节点 → 全屏星域详情（预选对应能力）
//  点击非节点区域 → 全屏星域详情（默认第一个节点）
//

import SwiftUI

// MARK: - 雷达维度数据结构

private struct RadarDimension {
    let name: String
    let icon: String
    let score: Double
    let color: Color
    let abilityType: String   // 对应 AbilityScore.type，用于跳转详情时预选
}

// MARK: - 页面数据模型

private struct StarPage: Identifiable {
    let id: String                  // "workplace" / "family" / "personal"
    let label: String
    let accent: Color
    let skills: [SkillCatalogItem]
}

// MARK: - 根视图

struct SkillConstellationView: View {
    @ObservedObject private var skillsVM  = SkillsViewModel.shared
    @ObservedObject private var tasksVM   = TaskListViewModel.shared
    @ObservedObject private var abilityVM = AbilityRadarViewModel.shared
    @State private var currentPage = 0

    // ── 解锁特效 ──────────────────────────────────────────────────────────────
    @State private var showUnlockEffect   = false
    @State private var unlockingSkillName = ""
    @State private var celebratedSkillIds: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "wsg_celebrated_skill_ids") ?? [])
    }()

    private var pages: [StarPage] {
        let defs: [(String, String, Color)] = [
            ("workplace", "职场雷达", Color(hex: "#45B7D1")),
            ("family",    "家庭雷达", Color(hex: "#E84393")),
            ("personal",  "成长雷达", Color(hex: "#FFEAA7")),
        ]
        return defs.compactMap { id, label, accent in
            let raw = skillsVM.categories.first { $0.id == id }?.skills ?? []
            return StarPage(id: id, label: label, accent: accent,
                            skills: representativeSix(raw))
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                    StarCardView(
                        page: page,
                        tasks: tasksVM.tasks,
                        abilities: abilityVM.abilities
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 262)
            .onAppear { abilityVM.load() }

            // 页面指示点（3个）
            HStack(spacing: 5) {
                ForEach(0..<pages.count, id: \.self) { i in
                    let isActive = i == currentPage
                    Capsule()
                        .fill(isActive
                              ? (i < pages.count ? pages[i].accent : Color.cyan)
                              : Color.white.opacity(0.22))
                        .frame(width: isActive ? 14 : 5, height: 4)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7),
                                   value: currentPage)
                }
            }
        }
        .onAppear {
            tasksVM.loadTasks()
            checkForNewlyUnlocked()
        }
        .onChange(of: skillsVM.selectedSkills) { _ in checkForNewlyUnlocked() }
        .overlay {
            if showUnlockEffect {
                SkillUnlockEffect(isShowing: $showUnlockEffect,
                                  skillName: unlockingSkillName)
            }
        }
    }

    private func checkForNewlyUnlocked() {
        for category in skillsVM.categories {
            for skill in category.skills where skill.selected {
                guard !celebratedSkillIds.contains(skill.skillId) else { continue }
                celebratedSkillIds.insert(skill.skillId)
                UserDefaults.standard.set(Array(celebratedSkillIds),
                                          forKey: "wsg_celebrated_skill_ids")
                unlockingSkillName = skill.name
                showUnlockEffect   = true
                return
            }
        }
    }

    private func representativeSix(_ skills: [SkillCatalogItem]) -> [SkillCatalogItem] {
        guard skills.count > 6 else { return skills }
        let step = Double(skills.count - 1) / 5.0
        return (0..<6).map { i in skills[Int((Double(i) * step).rounded())] }
    }
}

// MARK: - 域专属雷达卡片

private struct StarCardView: View {
    let page: StarPage
    let tasks: [TaskItem]
    let abilities: [AbilityScore]

    @State private var showDetail          = false
    @State private var selectedAbilityNav: String? = nil   // 跳转时传给详情的预选能力

    // ── 根据域生成维度（含 abilityType 供跳转使用）────────────────────────
    private var dimensions: [RadarDimension] {
        let ab = abilityMap
        switch page.id {
        case "workplace":
            return [
                RadarDimension(name: "影响力", icon: "⚡",
                               score: ab["influence"] ?? 0, color: Color(hex: "#FFD700"),
                               abilityType: "influence"),
                RadarDimension(name: "控制力", icon: "🎯",
                               score: ab["control"]   ?? 0, color: Color(hex: "#45B7D1"),
                               abilityType: "control"),
                RadarDimension(name: "执行力", icon: "🚀",
                               score: ab["execution"] ?? 0, color: Color(hex: "#FB923C"),
                               abilityType: "execution"),
                RadarDimension(name: "防御力", icon: "🛡",
                               score: ab["defense"]   ?? 0, color: Color(hex: "#34D399"),
                               abilityType: "defense"),
                RadarDimension(name: "洞察力", icon: "🔭",
                               score: ab["insight"]   ?? 0, color: Color(hex: "#A78BFA"),
                               abilityType: "insight"),
                RadarDimension(name: "共情力", icon: "💞",
                               score: ab["empathy"]   ?? 0, color: Color(hex: "#F472B6"),
                               abilityType: "empathy"),
            ]
        case "family":
            let emp = ab["empathy"]  ?? 0
            let ins = ab["insight"]  ?? 0
            return [
                RadarDimension(name: "亲密度", icon: "💖",
                               score: emp,             color: Color(hex: "#F472B6"),
                               abilityType: "empathy"),
                RadarDimension(name: "沟通力", icon: "💬",
                               score: (emp + ins) / 2, color: Color(hex: "#E84393"),
                               abilityType: "empathy"),
                RadarDimension(name: "陪伴力", icon: "🌸",
                               score: emp * 0.85,      color: Color(hex: "#FB7185"),
                               abilityType: "empathy"),
                RadarDimension(name: "理解力", icon: "🫂",
                               score: ins,             color: Color(hex: "#C084FC"),
                               abilityType: "insight"),
            ]
        default: // "personal"
            return [
                RadarDimension(name: "情绪力", icon: "🌊",
                               score: ab["empathy"]   ?? 0, color: Color(hex: "#FBBF24"),
                               abilityType: "empathy"),
                RadarDimension(name: "自省力", icon: "🔍",
                               score: ab["insight"]   ?? 0, color: Color(hex: "#A78BFA"),
                               abilityType: "insight"),
                RadarDimension(name: "复原力", icon: "🌱",
                               score: ab["defense"]   ?? 0, color: Color(hex: "#34D399"),
                               abilityType: "defense"),
                RadarDimension(name: "成长力", icon: "✨",
                               score: ab["execution"] ?? 0, color: Color(hex: "#FFEAA7"),
                               abilityType: "execution"),
            ]
        }
    }

    private var abilityMap: [String: Double] {
        Dictionary(abilities.map { ($0.type, $0.score) }, uniquingKeysWith: { a, _ in a })
    }

    private var topGrowthAbility: AbilityScore? {
        let relevant: [String]
        switch page.id {
        case "workplace": relevant = ["influence", "control", "execution", "defense", "insight", "empathy"]
        case "family":    relevant = ["empathy", "insight"]
        default:          relevant = ["empathy", "insight", "defense", "execution"]
        }
        return abilities
            .filter { relevant.contains($0.type) }
            .max(by: { $0.monthlyGrowth < $1.monthlyGrowth })
    }

    private var latestEvent: AbilityEvent? {
        let relevant: [String]
        switch page.id {
        case "workplace": relevant = ["influence", "control", "execution"]
        case "family":    relevant = ["empathy"]
        default:          relevant = ["insight", "defense"]
        }
        return abilities
            .filter { relevant.contains($0.type) }
            .flatMap { $0.recentEvents }
            .first
    }

    // 非节点点击时使用第一个维度的 abilityType
    private var firstAbilityType: String {
        dimensions.first?.abilityType ?? "influence"
    }

    var body: some View {
        ZStack {
            // ── 星空背景 ──────────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(hex: "#050B1A"), Color(hex: "#0D1B3E")],
                    center: .center, startRadius: 0, endRadius: 240
                ))
                .overlay {
                    Canvas { ctx, size in
                        var seed: UInt64 = 98765
                        func rand() -> Double {
                            seed = seed &* 6364136223846793005 &+ 1442695040888963407
                            return Double(seed >> 33) / Double(UInt32.max)
                        }
                        for _ in 0..<80 {
                            let x = rand() * Double(size.width)
                            let y = rand() * Double(size.height)
                            let r = rand() * 0.5 + 0.4
                            let op = rand() * 0.5 + 0.2
                            let rect = CGRect(x: x-r, y: y-r, width: r*2, height: r*2)
                            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(op)))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 0) {
                // ── 标题行 ────────────────────────────────────────────────
                HStack(alignment: .firstTextBaseline) {
                    Text(page.label)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(page.accent)
                    Spacer()
                    let active = page.skills.filter(\.selected).count
                    Text("\(active)/\(page.skills.count) 已激活")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.32))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 4)

                // ── 域专属雷达图（节点可点击）────────────────────────────
                GeometryReader { geo in
                    DomainRadarCanvas(
                        dimensions: dimensions,
                        size: min(geo.size.width * 0.95, geo.size.height * 1.8),
                        accent: page.accent,
                        onNodeTap: { abilityType in
                            // 节点点击：预选该能力，优先级高于卡片整体点击
                            selectedAbilityNav = abilityType
                            showDetail = true
                        }
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: 140)
                .clipped()

                // ── 分隔线 ────────────────────────────────────────────────
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)

                // ── 底部统计行 ────────────────────────────────────────────
                bottomStats
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(page.accent.opacity(0.20), lineWidth: 0.8)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture {
            // 整张卡片点击（非节点区域）：默认选第一个节点
            selectedAbilityNav = firstAbilityType
            showDetail = true
        }
        .padding(.horizontal, 16)
        .fullScreenCover(isPresented: $showDetail) {
            StarMapDetailView(
                categoryId: page.id,
                label: page.label,
                accent: page.accent,
                skills: page.skills,
                tasks: tasks,
                initialAbilityType: selectedAbilityNav
            )
        }
    }

    // ── 底部三栏统计 ──────────────────────────────────────────────────────────
    @ViewBuilder
    private var bottomStats: some View {
        HStack(spacing: 0) {
            let active = page.skills.filter(\.selected).count
            VStack(alignment: .leading, spacing: 2) {
                Text("已激活")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                Text("\(active) 项技能")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let top = topGrowthAbility, top.monthlyGrowth > 0 {
                VStack(alignment: .center, spacing: 2) {
                    Text("成长最快")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                    HStack(spacing: 3) {
                        Text(top.icon)
                            .font(.system(size: 10))
                        Text("+\(top.monthlyGrowth)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#34D399"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if let event = latestEvent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.date)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(page.accent.opacity(0.7))
                    Text(event.title)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - 域专属雷达 Canvas（支持4/6节点，节点可点击）

private struct DomainRadarCanvas: View {
    let dimensions: [RadarDimension]
    let size: CGFloat
    let accent: Color
    var onNodeTap: ((String) -> Void)? = nil   // 节点点击回调，传 abilityType

    private var nodeCount: Int { dimensions.count }

    var body: some View {
        ZStack {
            // ── 多边形网格 + 填充（Canvas） ───────────────────────────────
            Canvas { ctx, sz in
                let center = CGPoint(x: sz.width/2, y: sz.height/2)
                let maxR   = sz.width * 0.38

                for layer in 1...4 {
                    let r = maxR * CGFloat(layer) / 4
                    var path = Path()
                    for i in 0..<nodeCount {
                        let pt = nodePoint(center: center, radius: r, index: i, count: nodeCount)
                        if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                    }
                    path.closeSubpath()
                    let op = 0.04 + 0.03 * Double(layer)
                    ctx.stroke(path, with: .color(Color.white.opacity(op)), lineWidth: 0.5)
                }

                for i in 0..<nodeCount {
                    var p = Path()
                    p.move(to: center)
                    p.addLine(to: nodePoint(center: center, radius: maxR, index: i, count: nodeCount))
                    ctx.stroke(p, with: .color(accent.opacity(0.12)), lineWidth: 0.5)
                }

                var fillPath = Path()
                for (i, dim) in dimensions.enumerated() {
                    let r  = maxR * CGFloat(max(dim.score, 5) / 100)
                    let pt = nodePoint(center: center, radius: r, index: i, count: nodeCount)
                    if i == 0 { fillPath.move(to: pt) } else { fillPath.addLine(to: pt) }
                }
                fillPath.closeSubpath()
                ctx.fill(fillPath, with: .color(accent.opacity(0.15)))
                ctx.stroke(fillPath, with: .color(accent.opacity(0.5)), lineWidth: 1.2)
            }

            // ── 节点 + 标签（SwiftUI 层） ──────────────────────────────────
            let center = CGPoint(x: size/2, y: size/2)
            let maxR   = size * 0.38

            ForEach(Array(dimensions.enumerated()), id: \.offset) { i, dim in
                let hasData = dim.score > 0
                let r   = maxR * CGFloat(max(dim.score, 4) / 100)
                let pt  = nodePoint(center: center, radius: r, index: i, count: nodeCount)
                let lpt = nodePoint(center: center, radius: maxR + 16, index: i, count: nodeCount)
                let ns  = hasData ? CGFloat(dim.score / 100) * 10 + 5 : 4

                // 节点视觉（不参与点击）
                ZStack {
                    Circle()
                        .fill(hasData ? dim.color.opacity(0.35) : Color.white.opacity(0.04))
                        .frame(width: ns + 8, height: ns + 8)
                        .blur(radius: hasData ? 4 : 1)
                    Circle()
                        .fill(hasData ? dim.color : Color.white.opacity(0.15))
                        .frame(width: ns, height: ns)
                    if hasData {
                        Canvas { ctx, sz in
                            let cx = sz.width/2, cy = sz.height/2
                            let vL: CGFloat = 5, hL: CGFloat = 3
                            var v = Path()
                            v.move(to: CGPoint(x: cx, y: cy-vL))
                            v.addLine(to: CGPoint(x: cx, y: cy+vL))
                            var h = Path()
                            h.move(to: CGPoint(x: cx-hL, y: cy))
                            h.addLine(to: CGPoint(x: cx+hL, y: cy))
                            ctx.stroke(v, with: .color(.white.opacity(0.85)), lineWidth: 0.7)
                            ctx.stroke(h, with: .color(.white.opacity(0.55)), lineWidth: 0.7)
                        }
                        .frame(width: ns + 4, height: ns + 4)
                    }
                }
                .position(pt)
                .allowsHitTesting(false)

                // 透明点击区（比视觉节点更大，确保易点击）
                Circle()
                    .fill(Color.clear)
                    .frame(width: max(ns + 20, 36), height: max(ns + 20, 36))
                    .contentShape(Circle())
                    .position(pt)
                    .onTapGesture {
                        onNodeTap?(dim.abilityType)
                    }

                // 维度标签（不参与点击）
                VStack(spacing: 0) {
                    Text(dim.icon)
                        .font(.system(size: 10))
                    Text(dim.name)
                        .font(.system(size: 7.5,
                                      weight: hasData ? .semibold : .regular,
                                      design: .rounded))
                        .foregroundColor(hasData ? .white.opacity(0.8) : .white.opacity(0.2))
                        .lineLimit(1)
                        .fixedSize()
                }
                .position(lpt)
                .allowsHitTesting(false)
            }
        }
        .frame(width: size, height: size)
    }

    private func nodePoint(center: CGPoint, radius: CGFloat,
                           index: Int, count: Int) -> CGPoint {
        let angle = (CGFloat(index) * (360.0 / CGFloat(count)) - 90) * .pi / 180
        return CGPoint(x: center.x + radius * cos(angle),
                       y: center.y + radius * sin(angle))
    }
}

// MARK: - 原星节点视图（供其他页面复用）

struct PremiumStarNodeView: View {
    let skill: SkillCatalogItem
    let accent: Color

    private var nodeColor: Color {
        skill.coverColor.map { Color(hex: $0) } ?? accent
    }

    var body: some View {
        let active = skill.selected
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(nodeColor)
                    .frame(width: 40, height: 40)
                    .blur(radius: 12)
                    .opacity(active ? 0.15 : 0.03)
                Circle()
                    .fill(nodeColor)
                    .frame(width: 20, height: 20)
                    .blur(radius: 5)
                    .opacity(active ? 0.40 : 0.05)
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(active ? 1.0 : 0.15)
                Canvas { ctx, size in
                    let cx  = size.width  / 2
                    let cy  = size.height / 2
                    let vL: CGFloat = active ? 11 : 5
                    let hL: CGFloat = active ? 7  : 3
                    let wo: Double  = active ? 0.80 : 0.12
                    let ho: Double  = active ? 0.60 : 0.08
                    var vPath = Path()
                    vPath.move(to: CGPoint(x: cx, y: cy - vL))
                    vPath.addLine(to: CGPoint(x: cx, y: cy + vL))
                    var hPath = Path()
                    hPath.move(to: CGPoint(x: cx - hL, y: cy))
                    hPath.addLine(to: CGPoint(x: cx + hL, y: cy))
                    ctx.stroke(vPath, with: .color(.white.opacity(wo)), lineWidth: 0.8)
                    ctx.stroke(hPath, with: .color(.white.opacity(ho)), lineWidth: 0.8)
                }
                .frame(width: 32, height: 32)
            }
            Text(skill.name)
                .font(.system(size: 8.5,
                              weight: active ? .semibold : .regular,
                              design: .rounded))
                .foregroundColor(active ? .white.opacity(0.88) : .white.opacity(0.18))
                .lineLimit(1)
                .fixedSize()
        }
    }
}
