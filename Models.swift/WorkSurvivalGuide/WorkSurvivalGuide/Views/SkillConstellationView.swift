//
//  SkillConstellationView.swift
//  WorkSurvivalGuide
//
//  Swipeable constellation card — premium galaxy visual rendering
//

import SwiftUI

// MARK: - Data model (unchanged)

private struct StarPage: Identifiable {
    let id: String              // "workplace" / "family" / "personal"
    let label: String
    let accent: Color
    let skills: [SkillCatalogItem]
}

// MARK: - Root view (unchanged data logic)

struct SkillConstellationView: View {
    @ObservedObject private var skillsVM = SkillsViewModel.shared
    @ObservedObject private var tasksVM  = TaskListViewModel.shared
    @State private var currentPage = 0

    // ── Unlock effect ─────────────────────────────────────────────────────────
    @State private var showUnlockEffect   = false
    @State private var unlockingSkillName = ""
    /// Skill IDs for which we've already played the unlock celebration.
    /// Persisted so the effect is shown exactly once per skill across launches.
    @State private var celebratedSkillIds: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "wsg_celebrated_skill_ids") ?? [])
    }()

    private var pages: [StarPage] {
        let defs: [(String, String, Color)] = [
            ("workplace", "职场星图", Color(hex: "#45B7D1")),
            ("family",    "家庭星图", Color(hex: "#E84393")),
            ("personal",  "成长星图", Color(hex: "#FFEAA7")),
        ]
        return defs.compactMap { id, label, accent in
            let raw = skillsVM.categories.first { $0.id == id }?.skills ?? []
            guard !raw.isEmpty else { return nil }
            return StarPage(id: id, label: label, accent: accent,
                            skills: representativeSix(raw))
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            if !pages.isEmpty {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                        StarCardView(page: page, tasks: tasksVM.tasks)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 262)
                .onChange(of: pages.count) { newCount in
                    if currentPage >= newCount { currentPage = max(0, newCount - 1) }
                }

                // Page indicator dots
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
        }
        .onAppear {
            tasksVM.loadTasks()
            checkForNewlyUnlocked()
        }
        // Server may push updated skill states at any time; re-check on each change
        .onChange(of: skillsVM.selectedSkills) { _ in
            checkForNewlyUnlocked()
        }
        .overlay {
            if showUnlockEffect {
                SkillUnlockEffect(
                    isShowing: $showUnlockEffect,
                    skillName: unlockingSkillName
                )
            }
        }
    }

    // ── Unlock detection ──────────────────────────────────────────────────────

    /// Scans all categories for skills that are now selected but haven't been
    /// celebrated yet. When the server sets selected=true (confidence_score > 0.75),
    /// this fires the unlock effect exactly once per skill.
    private func checkForNewlyUnlocked() {
        for category in skillsVM.categories {
            for skill in category.skills where skill.selected {
                guard !celebratedSkillIds.contains(skill.skillId) else { continue }
                // Record as celebrated before triggering (prevents double-fire)
                celebratedSkillIds.insert(skill.skillId)
                UserDefaults.standard.set(Array(celebratedSkillIds),
                                          forKey: "wsg_celebrated_skill_ids")
                unlockingSkillName = skill.name
                showUnlockEffect   = true
                return  // one celebration at a time; next check will catch others
            }
        }
    }

    private func representativeSix(_ skills: [SkillCatalogItem]) -> [SkillCatalogItem] {
        guard skills.count > 6 else { return skills }
        let step = Double(skills.count - 1) / 5.0
        return (0..<6).map { i in skills[Int((Double(i) * step).rounded())] }
    }
}

// MARK: - Card view

private struct StarCardView: View {
    let page: StarPage
    let tasks: [TaskItem]

    @State private var showDetail = false

    private static let nodeLayouts: [Int: ([CGPoint], [(Int, Int)])] = [
        1: ([CGPoint(x: 0.50, y: 0.45)], []),
        2: ([CGPoint(x: 0.28, y: 0.42), CGPoint(x: 0.72, y: 0.48)],
            [(0, 1)]),
        3: ([CGPoint(x: 0.20, y: 0.32), CGPoint(x: 0.64, y: 0.18), CGPoint(x: 0.78, y: 0.65)],
            [(0, 1), (1, 2), (0, 2)]),
        4: ([CGPoint(x: 0.18, y: 0.25), CGPoint(x: 0.74, y: 0.20),
             CGPoint(x: 0.16, y: 0.72), CGPoint(x: 0.80, y: 0.68)],
            [(0, 1), (2, 3), (0, 2), (1, 3), (0, 3)]),
        5: ([CGPoint(x: 0.14, y: 0.22), CGPoint(x: 0.50, y: 0.10),
             CGPoint(x: 0.83, y: 0.27), CGPoint(x: 0.20, y: 0.70),
             CGPoint(x: 0.80, y: 0.65)],
            [(0, 1), (1, 2), (0, 3), (2, 4), (3, 4), (1, 3)]),
        6: ([CGPoint(x: 0.13, y: 0.22), CGPoint(x: 0.47, y: 0.09),
             CGPoint(x: 0.80, y: 0.24), CGPoint(x: 0.19, y: 0.70),
             CGPoint(x: 0.55, y: 0.82), CGPoint(x: 0.84, y: 0.62)],
            [(0, 1), (1, 2), (0, 3), (1, 4), (2, 5), (3, 4), (4, 5), (1, 3)]),
    ]

    var body: some View {
        ZStack {
            // ── BACKGROUND: radial gradient #050B1A → #0D1B3E ──
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(hex: "#050B1A"), Color(hex: "#0D1B3E")],
                    center: .center,
                    startRadius: 0,
                    endRadius: 240
                ))
                // ── MICRO-STARS: 100 tiny dots drawn via Canvas ──
                .overlay {
                    Canvas { ctx, size in
                        var seed: UInt64 = 98765
                        func rand() -> Double {
                            seed = seed &* 6364136223846793005 &+ 1442695040888963407
                            return Double(seed >> 33) / Double(UInt32.max)
                        }
                        for _ in 0..<100 {
                            let x  = rand() * Double(size.width)
                            let y  = rand() * Double(size.height)
                            let r  = rand() * 0.5 + 0.5        // radius 0.5-1pt → diameter 1-2pt
                            let op = rand() * 0.5 + 0.3        // opacity 0.3-0.8
                            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(op)))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

            // ── CARD CONTENT ──
            VStack(alignment: .leading, spacing: 0) {

                // Header
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
                .padding(.bottom, 6)

                // ── CONSTELLATION CANVAS ──
                GeometryReader { geo in
                    let count  = max(1, min(page.skills.count, 6))
                    let layout = Self.nodeLayouts[count] ?? Self.nodeLayouts[6]!
                    let pts    = layout.0.map {
                        CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height)
                    }
                    let edges  = layout.1

                    ZStack {
                        // Constellation lines — cyan #00D4FF with glow shadow
                        Path { path in
                            for (a, b) in edges where a < pts.count && b < pts.count {
                                path.move(to: pts[a])
                                path.addLine(to: pts[b])
                            }
                        }
                        .stroke(Color(hex: "#00D4FF").opacity(0.25), lineWidth: 0.8)
                        .shadow(color: Color(hex: "#00D4FF").opacity(0.55), radius: 3)

                        // Premium star nodes
                        ForEach(Array(page.skills.enumerated()), id: \.offset) { i, skill in
                            if i < pts.count {
                                PremiumStarNodeView(skill: skill, accent: page.accent)
                                    .position(pts[i])
                            }
                        }
                    }
                }
                .frame(height: 138)
                .clipped()

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Timeline — tap to open StarMapDetailView
                GalaxyTimelineView(tasks: tasks)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .contentShape(Rectangle())
                    .onTapGesture { showDetail = true }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(page.accent.opacity(0.20), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
        .sheet(isPresented: $showDetail) {
            StarMapDetailView(
                categoryId: page.id,
                label: page.label,
                accent: page.accent,
                skills: page.skills,
                tasks: tasks
            )
        }
    }
}

// MARK: - Premium star node

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
                // Layer 1: Large blur halo — 40pt, 0.15 opacity
                Circle()
                    .fill(nodeColor)
                    .frame(width: 40, height: 40)
                    .blur(radius: 12)
                    .opacity(active ? 0.15 : 0.03)

                // Layer 2: Medium glow — 20pt, 0.4 opacity
                Circle()
                    .fill(nodeColor)
                    .frame(width: 20, height: 20)
                    .blur(radius: 5)
                    .opacity(active ? 0.40 : 0.05)

                // Layer 3: Bright core — 6pt white center
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(active ? 1.0 : 0.15)

                // Layer 4: 4-point star spike via Canvas
                Canvas { ctx, size in
                    let cx  = size.width  / 2
                    let cy  = size.height / 2
                    let vL: CGFloat = active ? 11 : 5     // vertical spike length
                    let hL: CGFloat = active ? 7  : 3     // horizontal spike length
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
