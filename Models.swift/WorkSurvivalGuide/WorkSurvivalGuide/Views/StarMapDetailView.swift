//
//  StarMapDetailView.swift
//  WorkSurvivalGuide
//
//  Detail page: larger constellation + major events list — opens from galaxy timeline tap
//

import SwiftUI

struct StarMapDetailView: View {
    let categoryId: String        // "workplace" / "family" / "personal"
    let label: String             // "职场星图" etc.
    let accent: Color
    let skills: [SkillCatalogItem]
    let tasks: [TaskItem]         // passed for GalaxyTimelineView

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var tasksVM = TaskListViewModel.shared

    @State private var majorEvents: [MajorEvent] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var selectedTask: TaskItem?

    // ── Node layout (mirrors StarCardView) ───────────────────────────────────

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

    // ── Page title ───────────────────────────────────────────────────────────

    private var pageTitle: String {
        switch categoryId {
        case "workplace": return "职场星域"
        case "family":    return "家庭星域"
        default:          return "成长星域"
        }
    }

    // ── Body ─────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            Color(hex: "#050B1A").ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        constellationSection
                            .padding(.top, 12)

                        Rectangle()
                            .fill(Color.white.opacity(0.07))
                            .frame(height: 0.5)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)

                        sessionListSection
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .task {
            await loadMajorEvents()
        }
    }

    // ── Network fetch ────────────────────────────────────────────────────────

    @MainActor
    private func loadMajorEvents() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        do {
            majorEvents = try await NetworkManager.shared.getMajorEvents(
                category: categoryId, limit: 10
            )
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    // ── Header bar ───────────────────────────────────────────────────────────

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

            let active = skills.filter(\.selected).count
            Text("\(active)/\(skills.count) 已激活")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(accent.opacity(0.85))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(accent.opacity(0.15)))
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
    }

    // ── Large constellation section ──────────────────────────────────────────

    private var constellationSection: some View {
        ZStack {
            // Deep space background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(hex: "#050B1A"), Color(hex: "#0D1B3E")],
                    center: .center, startRadius: 0, endRadius: 300
                ))
                .overlay {
                    Canvas { ctx, size in
                        var seed: UInt64 = 24680
                        func rand() -> Double {
                            seed = seed &* 6364136223846793005 &+ 1442695040888963407
                            return Double(seed >> 33) / Double(UInt32.max)
                        }
                        for _ in 0..<120 {
                            let x  = rand() * Double(size.width)
                            let y  = rand() * Double(size.height)
                            let r  = rand() * 0.6 + 0.4
                            let op = rand() * 0.5 + 0.3
                            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(op)))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

            VStack(spacing: 0) {
                // Category label + active count
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(accent)
                    Spacer()
                    let active = skills.filter(\.selected).count
                    Text("\(active)/\(skills.count) 已激活")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.32))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

                // Larger constellation canvas (~220pt)
                GeometryReader { geo in
                    let count  = max(1, min(skills.count, 6))
                    let layout = Self.nodeLayouts[count] ?? Self.nodeLayouts[6]!
                    let pts    = layout.0.map {
                        CGPoint(x: $0.x * geo.size.width, y: $0.y * geo.size.height)
                    }
                    let edges  = layout.1

                    ZStack {
                        Path { path in
                            for (a, b) in edges where a < pts.count && b < pts.count {
                                path.move(to: pts[a])
                                path.addLine(to: pts[b])
                            }
                        }
                        .stroke(Color(hex: "#00D4FF").opacity(0.25), lineWidth: 1.0)
                        .shadow(color: Color(hex: "#00D4FF").opacity(0.55), radius: 4)

                        ForEach(Array(skills.enumerated()), id: \.offset) { i, skill in
                            if i < pts.count {
                                PremiumStarNodeView(skill: skill, accent: accent)
                                    .position(pts[i])
                            }
                        }
                    }
                }
                .frame(height: 220)
                .clipped()

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Galaxy timeline
                GalaxyTimelineView(tasks: tasks)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(accent.opacity(0.20), lineWidth: 0.8)
        )
        .padding(.horizontal, 16)
    }

    // ── Session list ─────────────────────────────────────────────────────────

    private var sessionListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(accent.opacity(0.8))
                Text("重大事件")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                if isLoading {
                    ProgressView()
                        .tint(accent)
                        .scaleEffect(0.7)
                } else {
                    Text("\(majorEvents.count) 条")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .padding(.horizontal, 20)

            if isLoading && majorEvents.isEmpty {
                // Loading state
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(accent)
                    Text("正在加载重大事件…")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)

            } else if let err = loadError {
                // Error state
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundColor(.orange.opacity(0.6))
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        Task { await loadMajorEvents() }
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .padding(.horizontal, 40)

            } else if majorEvents.isEmpty {
                // Empty state
                VStack(spacing: 10) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.15))
                    Text("暂无重大事件记录")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.25))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)

            } else {
                VStack(spacing: 10) {
                    ForEach(majorEvents) { event in
                        eventCard(event)
                            .onTapGesture { navigateTo(event) }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // ── Single event card ────────────────────────────────────────────────────

    @ViewBuilder
    private func eventCard(_ event: MajorEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row
            Text(event.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)

            // Summary row
            if !event.summary.isEmpty {
                Text(event.summary)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }

            // Bottom row: date + skill badge + chevron
            HStack(spacing: 8) {
                Text(formattedDate(event.createdAt))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "#00D4FF").opacity(0.75))

                if let skill = event.skillName, !skill.isEmpty {
                    Text(skill)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(accent.opacity(0.9))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(accent.opacity(0.15)))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.28))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
        )
    }

    // ── Navigation ───────────────────────────────────────────────────────────

    private func navigateTo(_ event: MajorEvent) {
        // Prefer a fully-loaded TaskItem from the existing list
        if let existing = tasksVM.tasks.first(where: { $0.id == event.sessionId }) {
            selectedTask = existing
        } else {
            // Fallback: create minimal TaskItem; TaskDetailView will load full data
            selectedTask = event.toTaskItem()
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM月dd日 HH:mm"
        return fmt.string(from: date)
    }
}
