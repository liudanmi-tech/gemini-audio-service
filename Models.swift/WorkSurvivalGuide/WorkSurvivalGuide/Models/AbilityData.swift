//
//  AbilityData.swift
//  WorkSurvivalGuide
//
//  六维能力评分系统数据模型
//

import Foundation

// MARK: - 能力大事件
struct AbilityEvent: Codable, Identifiable {
    let sessionId: String
    let date: String
    let title: String
    let summary: String
    let scoreContribution: Int
    let abilityType: String?   // "control" / "defense" / ...
    let abilityName: String?   // "控制力" / "防御力" / ...
    let skillName: String?     // 具体技能名称
    let outcome: String?       // "breakthrough" / "practice" / "setback"

    var id: String { sessionId + date }

    enum CodingKeys: String, CodingKey {
        case sessionId        = "session_id"
        case date, title, summary
        case scoreContribution = "score_contribution"
        case abilityType      = "ability_type"
        case abilityName      = "ability_name"
        case skillName        = "skill_name"
        case outcome
    }
}

// MARK: - 单个能力维度
struct AbilityScore: Codable, Identifiable {
    let type: String          // empathy / control / insight / influence / defense / execution
    let name: String          // 共情力 / 控制力 / ...
    let icon: String          // emoji
    let score: Double         // 0-100
    let level: String         // 萌芽期 / 探索期 / 成长期 / 精通期 / 大师期
    let levelEmoji: String
    let monthlyGrowth: Int
    let relatedSkills: [String]
    let recentEvents: [AbilityEvent]
    let growthTrend: [Double] // 4 个周期数据（-3w/-2w/-1w/本周）

    var id: String { type }

    // 显示顺序（六边形节点顺序：顶 / 右上 / 右下 / 底 / 左下 / 左上）
    static let displayOrder = ["influence", "control", "execution", "defense", "empathy", "insight"]

    enum CodingKeys: String, CodingKey {
        case type, name, icon, score, level
        case levelEmoji    = "level_emoji"
        case monthlyGrowth = "monthly_growth"
        case relatedSkills = "related_skills"
        case recentEvents  = "recent_events"
        case growthTrend   = "growth_trend"
    }
}

// MARK: - 勋章
struct AbilityBadge: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let desc: String
}

// MARK: - API 响应包装
struct AbilityScoresData: Codable {
    let abilities: [AbilityScore]
    let newBadges: [AbilityBadge]

    enum CodingKeys: String, CodingKey {
        case abilities
        case newBadges = "new_badges"
    }
}

struct AbilityScoresResponse: Codable {
    let code: Int
    let message: String
    let data: AbilityScoresData?
}
