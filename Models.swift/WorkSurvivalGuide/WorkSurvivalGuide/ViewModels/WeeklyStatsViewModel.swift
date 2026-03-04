//
//  WeeklyStatsViewModel.swift
//  WorkSurvivalGuide
//
//  周报统计数据管理：心情曲线 / 技能雷达 / 社交能量
//

import Foundation
import SwiftUI

@MainActor
class WeeklyStatsViewModel: ObservableObject {

    static let shared = WeeklyStatsViewModel()

    @Published var stats: WeeklyStats? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var selectedRange: TimeRange = .thisWeek

    enum TimeRange: String, CaseIterable {
        case thisWeek  = "This Week"
        case lastWeek  = "Last Week"
        case month30   = "Past 30 Days"
    }

    private init() {}

    // MARK: - Date helpers

    var periodLabel: String {
        let (s, e) = dateRange
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let eFmt = DateFormatter()
        eFmt.dateFormat = "MMM d"
        return "\(fmt.string(from: s)) – \(eFmt.string(from: e))"
    }

    var dateRange: (Date, Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        switch selectedRange {
        case .thisWeek:
            let weekday = cal.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
            let sunday = cal.date(byAdding: .day, value: 6, to: monday)!
            return (monday, sunday)
        case .lastWeek:
            let weekday = cal.component(.weekday, from: today)
            let daysFromMonday = (weekday + 5) % 7
            let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
            let lastMonday = cal.date(byAdding: .day, value: -7, to: thisMonday)!
            let lastSunday = cal.date(byAdding: .day, value: 6, to: lastMonday)!
            return (lastMonday, lastSunday)
        case .month30:
            let start = cal.date(byAdding: .day, value: -29, to: today)!
            return (start, today)
        }
    }

    private var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: - Load

    func load() {
        guard !isLoading else { return }
        let (start, end) = dateRange
        let startStr = dateFormatter.string(from: start)
        let endStr   = dateFormatter.string(from: end)

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await NetworkManager.shared.getWeeklyStats(
                    startDate: startStr,
                    endDate: endStr
                )
                self.stats = result
            } catch {
                self.errorMessage = "Failed to load stats"
            }
            self.isLoading = false
        }
    }

    func switchRange(_ range: TimeRange) {
        guard range != selectedRange else { return }
        selectedRange = range
        stats = nil
        load()
    }

    // MARK: - Computed helpers

    /// 本周有录音的天数
    var activeDays: Int {
        stats?.mood_series.filter { ($0.session_count) > 0 }.count ?? 0
    }

    /// 本周总录音时长（分钟）
    var totalMinutes: Int {
        Int((stats?.sessions.reduce(0) { $0 + $1.duration_sec } ?? 0) / 60)
    }

    /// 技能雷达最高分
    var topRadarItem: RadarItem? {
        stats?.skill_radar.max(by: { $0.score < $1.score })
    }

    /// 社交能量第一名
    var topSocialItem: SocialEnergyItem? {
        stats?.social_energy.first
    }

    // MARK: - Category helpers (shared by views)

    static func categoryColor(for id: String) -> Color {
        switch id {
        case "work_life":       return Color(hex: "#45B7D1")
        case "campus_life":     return Color(hex: "#A78BFA")
        case "relationships":   return Color(hex: "#F472B6")
        case "family":          return Color(hex: "#FB923C")
        case "personal_growth": return Color(hex: "#34D399")
        case "life_skills":     return Color(hex: "#FBBF24")
        default:                return Color(hex: "#5E7C8B")
        }
    }

    static func categoryEmoji(for id: String) -> String {
        switch id {
        case "work_life":       return "🏢"
        case "campus_life":     return "🎓"
        case "relationships":   return "💕"
        case "family":          return "🏠"
        case "personal_growth": return "🌱"
        case "life_skills":     return "⚡"
        default:                return "💬"
        }
    }

    static func categoryName(for id: String) -> String {
        switch id {
        case "work_life":       return "Work Life"
        case "campus_life":     return "Campus"
        case "relationships":   return "Relationships"
        case "family":          return "Family"
        case "personal_growth": return "Growth"
        case "life_skills":     return "Life Skills"
        default:                return "Other"
        }
    }

    static func moodColor(for polarity: String?) -> Color {
        switch polarity {
        case "positive": return Color(hex: "#FB923C")
        case "negative": return Color(hex: "#60A5FA")
        default:         return Color(hex: "#94A3B8")
        }
    }
}
