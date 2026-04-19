//
//  WeeklyStatsView.swift
//  WorkSurvivalGuide
//
//  周报三卡轮播（心情曲线 / 技能雷达 / 社交能量）+ 详情 Sheet
//

import SwiftUI
import Charts

// MARK: - Carousel Container

struct WeeklyStatsCarouselView: View {
    @StateObject private var vm = WeeklyStatsViewModel.shared
    @State private var activeCard = 0
    @State private var detailCard: CardType? = nil

    enum CardType: Int, Identifiable {
        case mood = 0, radar = 1, social = 2
        var id: Int { rawValue }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }

    private var radarStartDate: String { dateFormatter.string(from: vm.dateRange.0) }
    private var radarEndDate: String   { dateFormatter.string(from: vm.dateRange.1) }

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $activeCard) {
                MoodCurveCard(stats: vm.stats, isLoading: vm.isLoading)
                    .tag(0)
                    .onTapGesture { detailCard = .mood }

                SkillsRadarCardView(
                    startDate: radarStartDate,
                    endDate: radarEndDate,
                    periodLabel: vm.periodLabel
                )
                .tag(1)
                .onTapGesture { detailCard = .radar }

                SocialEnergyCard(stats: vm.stats, isLoading: vm.isLoading)
                    .tag(2)
                    .onTapGesture { detailCard = .social }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 290)

            // Page dots
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(activeCard == i ? Color.white.opacity(0.8) : Color.white.opacity(0.25))
                        .frame(width: activeCard == i ? 6 : 4, height: activeCard == i ? 6 : 4)
                        .animation(.easeInOut(duration: 0.2), value: activeCard)
                }
            }
        }
        .onAppear { vm.load() }
        .sheet(item: $detailCard) { card in
            WeeklyStatsDetailSheet(vm: vm, initialCard: card)
        }
    }
}

// MARK: - Card Base

private struct CardBase<Content: View>: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    @ViewBuilder let content: Content

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
                        Text(title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(subtitle)
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

                content
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct LoadingCardContent: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView().progressViewStyle(.circular).tint(.white.opacity(0.4))
            Spacer()
        }
        .frame(height: 90)
    }
}

private struct EmptyCardContent: View {
    let message: String
    var body: some View {
        VStack(spacing: 6) {
            Text("—").font(.system(size: 24)).foregroundColor(.white.opacity(0.2))
            Text(message).font(.system(size: 11)).foregroundColor(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 90)
    }
}

// MARK: - Card 1: Mood Curve

private struct MoodCurveCard: View {
    let stats: WeeklyStats?
    let isLoading: Bool

    private var points: [(day: String, score: Double?, polarity: String?)] {
        stats?.mood_series.map { ($0.date, $0.score, $0.polarity) } ?? []
    }

    var body: some View {
        let vm = WeeklyStatsViewModel.shared
        CardBase(title: "😊 Mood Trend", subtitle: vm.periodLabel, accentColor: Color(hex: "#FB923C")) {
            if isLoading {
                LoadingCardContent()
            } else if points.filter({ $0.score != nil }).isEmpty {
                EmptyCardContent(message: "No recordings this period")
            } else {
                MoodSparkline(points: points)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .frame(height: 190)
            }
        }
    }
}

private struct MoodSparkline: View {
    let points: [(day: String, score: Double?, polarity: String?)]

    var body: some View {
        let filled = points.filter { $0.score != nil }
        if #available(iOS 16.0, *) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                    if let score = p.score {
                        LineMark(
                            x: .value("Day", i),
                            y: .value("Score", score)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: "#FB923C"), Color(hex: "#60A5FA")],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)

                        PointMark(x: .value("Day", i), y: .value("Score", score))
                            .foregroundStyle(WeeklyStatsViewModel.moodColor(for: p.polarity))
                            .symbolSize(28)
                    }
                }
                // neutral band
                RuleMark(y: .value("Neutral", 50))
                    .foregroundStyle(Color.white.opacity(0.1))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3]))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...100)
        }
    }
}

// MARK: - Skills Radar Sheet (used when opened from other contexts)

struct SkillsRadarSheet: View {
    let startDate: String
    let endDate: String
    let periodLabel: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                // Title bar
                HStack {
                    Text("⚡ Skills Radar")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(periodLabel)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

                SkillsRadarDetailPage(
                    startDate: startDate,
                    endDate: endDate,
                    periodLabel: periodLabel
                )
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

struct RadarChartMini: View {
    let items: [RadarItem]

    var body: some View {
        Canvas { ctx, size in
            let n = items.count
            guard n >= 1 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2 - 4

            // Background grid rings
            for ring in [0.33, 0.66, 1.0] {
                var gridPath = Path()
                for i in 0..<n {
                    let angle = angle(i: i, n: n)
                    let pt = point(center: center, r: maxR * ring, angle: angle)
                    if i == 0 { gridPath.move(to: pt) } else { gridPath.addLine(to: pt) }
                }
                gridPath.closeSubpath()
                ctx.stroke(gridPath, with: .color(.white.opacity(0.08)), lineWidth: 0.5)
            }

            // Axis lines
            for i in 0..<n {
                let angle = angle(i: i, n: n)
                var axisPath = Path()
                axisPath.move(to: center)
                axisPath.addLine(to: point(center: center, r: maxR, angle: angle))
                ctx.stroke(axisPath, with: .color(.white.opacity(0.1)), lineWidth: 0.5)
            }

            // Data polygon
            var dataPath = Path()
            for (i, item) in items.enumerated() {
                let angle = angle(i: i, n: n)
                let r = maxR * CGFloat(min(item.score / 100.0, 1.0))
                let pt = point(center: center, r: r, angle: angle)
                if i == 0 { dataPath.move(to: pt) } else { dataPath.addLine(to: pt) }
            }
            dataPath.closeSubpath()
            ctx.fill(dataPath, with: .color(Color(hex: "#45B7D1").opacity(0.3)))
            ctx.stroke(dataPath, with: .color(Color(hex: "#45B7D1").opacity(0.8)), lineWidth: 1.5)

            // Dots at each vertex
            for (i, item) in items.enumerated() {
                let angle = angle(i: i, n: n)
                let r = maxR * CGFloat(min(item.score / 100.0, 1.0))
                let pt = point(center: center, r: r, angle: angle)
                let dotRect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                ctx.fill(Path(ellipseIn: dotRect),
                         with: .color(WeeklyStatsViewModel.categoryColor(for: item.category_id)))
            }
        }
    }

    private func angle(i: Int, n: Int) -> Double {
        (2 * .pi * Double(i) / Double(n)) - .pi / 2
    }

    private func point(center: CGPoint, r: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + r * CGFloat(cos(angle)),
                y: center.y + r * CGFloat(sin(angle)))
    }
}

// MARK: - Card 3: Social Energy

private struct SocialEnergyCard: View {
    let stats: WeeklyStats?
    let isLoading: Bool

    var body: some View {
        let vm = WeeklyStatsViewModel.shared
        let items = stats?.social_energy.prefix(4).map { $0 } ?? []
        CardBase(title: "🌐 Social Energy", subtitle: vm.periodLabel, accentColor: Color(hex: "#34D399")) {
            if isLoading {
                LoadingCardContent()
            } else if items.isEmpty {
                EmptyCardContent(message: "No conversations this period")
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.category_id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(WeeklyStatsViewModel.categoryEmoji(for: item.category_id))
                                    .font(.system(size: 14))
                                    .frame(width: 20)
                                Text(WeeklyStatsViewModel.categoryName(for: item.category_id))
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                                Spacer()
                                Text("\(Int(item.pct * 100))%")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.07))
                                    Capsule()
                                        .fill(WeeklyStatsViewModel.categoryColor(for: item.category_id).opacity(0.75))
                                        .frame(width: geo.size.width * CGFloat(item.pct))
                                }
                            }
                            .frame(height: 10)
                        }
                        .padding(.bottom, 14)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 12)
                .frame(height: 190)
            }
        }
    }
}

// MARK: - Detail Sheet

struct WeeklyStatsDetailSheet: View {
    @ObservedObject var vm: WeeklyStatsViewModel
    let initialCard: WeeklyStatsCarouselView.CardType

    @State private var selectedCard: WeeklyStatsCarouselView.CardType
    @State private var highlightedSessionId: String? = nil   // 来自图表点击
    @Environment(\.dismiss) private var dismiss

    init(vm: WeeklyStatsViewModel, initialCard: WeeklyStatsCarouselView.CardType) {
        self.vm = vm
        self.initialCard = initialCard
        _selectedCard = State(initialValue: initialCard)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }
    private var radarStartDate: String { dateFormatter.string(from: vm.dateRange.0) }
    private var radarEndDate: String   { dateFormatter.string(from: vm.dateRange.1) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Range + card picker
                    VStack(spacing: 10) {
                        Picker("", selection: Binding(
                            get: { vm.selectedRange },
                            set: { vm.switchRange($0) }
                        )) {
                            ForEach(WeeklyStatsViewModel.TimeRange.allCases, id: \.self) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("", selection: $selectedCard) {
                            Text("Mood").tag(WeeklyStatsCarouselView.CardType.mood)
                            Text("Radar").tag(WeeklyStatsCarouselView.CardType.radar)
                            Text("Social").tag(WeeklyStatsCarouselView.CardType.social)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)

                    if selectedCard == .radar {
                        SkillsRadarDetailPage(
                            startDate: radarStartDate,
                            endDate: radarEndDate,
                            periodLabel: vm.periodLabel
                        )
                    } else {
                        // Chart area (fixed 180pt)
                        Group {
                            switch selectedCard {
                            case .mood:
                                MoodDetailChart(vm: vm, highlightedSessionId: $highlightedSessionId)
                            case .social:
                                SocialDetailChart(vm: vm)
                            case .radar:
                                EmptyView()
                            }
                        }
                        .frame(height: 180)
                        .padding(.horizontal, 16)

                        Divider().background(Color.white.opacity(0.1)).padding(.top, 8)

                        // Session list with scroll reader
                        sessionList
                    }
                }
            }
            .navigationTitle(
                selectedCard == .mood   ? "Mood Details"   :
                selectedCard == .radar  ? "Skills Radar"   :
                                          "Social Details"
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: Session list

    private var filteredSessions: [WeeklySession] {
        guard let sessions = vm.stats?.sessions else { return [] }
        switch selectedCard {
        case .mood:
            // 按日期排序（最新在前），与时间轴图表对应
            return sessions
                .filter { $0.mood_score != nil }
                .sorted { lhs, rhs in
                    (lhs.created_at ?? "") > (rhs.created_at ?? "")
                }
        case .social:
            return sessions.sorted { $0.duration_sec > $1.duration_sec }
        case .radar:
            return []
        }
    }

    private var sessionList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if vm.isLoading {
                        ProgressView().padding(40)
                    } else if filteredSessions.isEmpty {
                        Text("No recordings this period")
                            .font(.system(size: 14)).foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity).padding(40)
                    } else {
                        ForEach(filteredSessions) { session in
                            if let task = session.toTaskItem() {
                                NavigationLink(destination: TaskDetailView(task: task)) {
                                    WeeklySessionRow(
                                        session: session,
                                        cardType: selectedCard,
                                        isHighlighted: session.session_id == highlightedSessionId
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(session.session_id)
                            } else {
                                WeeklySessionRow(
                                    session: session,
                                    cardType: selectedCard,
                                    isHighlighted: false
                                )
                                .id(session.session_id)
                            }
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 72)
                        }
                    }
                }
            }
            .onChange(of: highlightedSessionId) { id in
                guard let id = id else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(id, anchor: .center)
                }
                // 2 秒后自动取消高亮
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        highlightedSessionId = nil
                    }
                }
            }
        }
    }
}

// MARK: - Detail Charts (180pt fixed)

private struct MoodDetailChart: View {
    @ObservedObject var vm: WeeklyStatsViewModel
    @Binding var highlightedSessionId: String?

    var body: some View {
        let points = vm.stats?.mood_series ?? []
        let hasData = points.contains { $0.score != nil }

        if vm.isLoading {
            HStack {
                Spacer()
                ProgressView().progressViewStyle(.circular).tint(.white.opacity(0.4))
                Spacer()
            }
            .frame(height: 180)
        } else if !hasData {
            VStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.15))
                Text("No mood data for this period")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.3))
                Text("Start recording to track your mood trends")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.2))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
        } else if #available(iOS 16.0, *) {
            Chart {
                ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                    if let score = p.score {
                        AreaMark(
                            x: .value("Day", i),
                            yStart: .value("Base", 50),
                            yEnd:   .value("Score", score)
                        )
                        .foregroundStyle(
                            score >= 50
                            ? Color(hex: "#FB923C").opacity(0.15)
                            : Color(hex: "#60A5FA").opacity(0.15)
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(x: .value("Day", i), y: .value("Score", score))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "#FB923C"), Color(hex: "#60A5FA")],
                                               startPoint: .top, endPoint: .bottom)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))

                        // 选中状态放大点
                        PointMark(x: .value("Day", i), y: .value("Score", score))
                            .foregroundStyle(WeeklyStatsViewModel.moodColor(for: p.polarity))
                            .symbolSize(p.session_id == highlightedSessionId ? 90 : 40)
                    }
                }
                RuleMark(y: .value("Neutral", 50))
                    .foregroundStyle(Color.white.opacity(0.15))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                    .annotation(position: .trailing) {
                        Text("50").font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 1)) { val in
                    if let i = val.as(Int.self), i < points.count {
                        AxisValueLabel {
                            Text(shortDay(from: points[i].date))
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { val in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel {
                        if let v = val.as(Int.self) {
                            Text("\(v)").font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
            }
            .chartYScale(domain: 0...100)
            .chartBackground { _ in Color.clear }
            // 点击图表节点
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { val in
                                    let plotOrigin = geo[proxy.plotAreaFrame].origin
                                    let xInPlot = val.location.x - plotOrigin.x
                                    guard xInPlot >= 0 else { return }
                                    guard let rawIndex: Int = proxy.value(atX: xInPlot) else { return }
                                    // 找最近的有数据节点
                                    let validPoints = points
                                        .enumerated()
                                        .filter { $0.element.score != nil && $0.element.session_id != nil }
                                    guard let closest = validPoints.min(by: {
                                        abs($0.offset - rawIndex) < abs($1.offset - rawIndex)
                                    }) else { return }
                                    withAnimation(.spring(response: 0.3)) {
                                        highlightedSessionId = closest.element.session_id
                                    }
                                }
                        )
                }
            }
        }
    }

    private func shortDay(from dateStr: String) -> String {
        let days = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateStr) else { return "" }
        let w = Calendar.current.component(.weekday, from: d)
        let idx = (w + 5) % 7
        return days[min(idx, 6)]
    }
}

private struct RadarDetailChart: View {
    @ObservedObject var vm: WeeklyStatsViewModel

    var body: some View {
        let items = vm.stats?.skill_radar ?? []
        if items.isEmpty {
            EmptyCardContent(message: "No skill data this period")
        } else {
            HStack(spacing: 16) {
                RadarChartMini(items: items)
                    .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.category_id) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(WeeklyStatsViewModel.categoryColor(for: item.category_id))
                                .frame(width: 8, height: 8)
                            Text(WeeklyStatsViewModel.categoryName(for: item.category_id))
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            if let d = item.delta {
                                Text(d >= 0 ? "↑\(Int(abs(d)))" : "↓\(Int(abs(d)))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(d >= 0 ? Color(hex: "#34D399") : Color(hex: "#F87171"))
                            }
                            Text("\(Int(item.score))")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(WeeklyStatsViewModel.categoryColor(for: item.category_id))
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct SocialDetailChart: View {
    @ObservedObject var vm: WeeklyStatsViewModel

    var body: some View {
        let items = vm.stats?.social_energy ?? []
        if items.isEmpty {
            EmptyCardContent(message: "No conversations this period")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.category_id) { item in
                    HStack(spacing: 10) {
                        Text(WeeklyStatsViewModel.categoryEmoji(for: item.category_id))
                            .font(.system(size: 16))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(WeeklyStatsViewModel.categoryName(for: item.category_id))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(Int(item.duration_min)) min · \(item.session_count) sessions")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07))
                                    Capsule()
                                        .fill(WeeklyStatsViewModel.categoryColor(for: item.category_id).opacity(0.8))
                                        .frame(width: geo.size.width * CGFloat(item.pct))
                                }
                            }
                            .frame(height: 7)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Session Row

struct WeeklySessionRow: View {
    let session: WeeklySession
    let cardType: WeeklyStatsCarouselView.CardType
    var isHighlighted: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 封面图（与 moment 卡片用同一 ImageLoaderView，自动带 JWT auth）
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(WeeklyStatsViewModel.categoryColor(for: session.scene_category ?? "").opacity(0.25))
                if let urlStr = session.thumbnail_url, !urlStr.isEmpty {
                    ImageLoaderView(
                        imageUrl: urlStr,
                        imageBase64: nil,
                        placeholder: "",
                        contentMode: .fill
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    Text(WeeklyStatsViewModel.categoryEmoji(for: session.scene_category ?? ""))
                        .font(.system(size: 22))
                }
            }
            .frame(width: 56, height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(hex: "#FB923C"), lineWidth: isHighlighted ? 2 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isHighlighted)
            )

            // 卡片标题 + 日期
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title ?? "Untitled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isHighlighted ? Color(hex: "#FB923C") : .white)
                    .lineLimit(1)
                    .animation(.easeInOut(duration: 0.3), value: isHighlighted)

                HStack(spacing: 6) {
                    Text(formattedDate)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    Text("·")
                        .foregroundColor(.white.opacity(0.2))
                    Text(WeeklyStatsViewModel.categoryName(for: session.scene_category ?? ""))
                        .font(.system(size: 11))
                        .foregroundColor(WeeklyStatsViewModel.categoryColor(for: session.scene_category ?? "").opacity(0.9))
                }
            }

            Spacer()

            // 卡片指标
            cardMetric
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isHighlighted
                ? Color(hex: "#FB923C").opacity(0.06)
                : Color.clear
        )
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }

    @ViewBuilder
    private var cardMetric: some View {
        switch cardType {
        case .mood:
            if let score = session.mood_score {
                VStack(spacing: 2) {
                    Text(moodEmoji(session.mood_polarity))
                        .font(.system(size: 18))
                    Text("\(score)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(WeeklyStatsViewModel.moodColor(for: session.mood_polarity))
                }
            }
        case .social:
            VStack(spacing: 2) {
                Text("\(session.duration_sec / 60)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Text("min")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.35))
            }
        case .radar:
            EmptyView()
        }
    }

    private var formattedDate: String {
        guard let str = session.created_at else { return "" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        guard let date = f.date(from: str) ?? f2.date(from: str) else { return str }
        let out = DateFormatter()
        out.dateFormat = "MMM d, h:mm a"
        return out.string(from: date)
    }

    private func moodEmoji(_ polarity: String?) -> String {
        switch polarity {
        case "positive": return "😊"
        case "negative": return "😔"
        default:         return "😐"
        }
    }

    private func confColor(_ v: Double) -> Color {
        if v >= 0.8 { return Color(hex: "#34D399") }
        if v >= 0.6 { return Color(hex: "#FBBF24") }
        return Color(hex: "#F87171")
    }

    private func shortSkillName(_ id: String) -> String {
        id.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

// MARK: - WeeklySession → TaskItem conversion

private extension WeeklySession {
    func toTaskItem() -> TaskItem? {
        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        guard let dateStr = created_at,
              let date = isoFull.date(from: dateStr) ?? isoBasic.date(from: dateStr) else {
            return nil
        }

        return TaskItem(
            id: session_id,
            title: title ?? "Untitled",
            startTime: date,
            endTime: nil,
            duration: duration_sec,
            tags: [],
            status: .archived,
            emotionScore: mood_score,
            speakerCount: nil,
            summary: nil,
            cardTitle: title,
            coverImageUrl: thumbnail_url,
            progressDescription: nil
        )
    }
}
