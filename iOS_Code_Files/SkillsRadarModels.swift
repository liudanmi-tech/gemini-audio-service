//
//  SkillsRadarModels.swift
//  WorkSurvivalGuide
//
//  新版技能雷达数据模型（Level1=场景, Level2=用户选的子技能）
//

import Foundation
import SwiftUI

// MARK: - Scene Insight SSE Models

/// 单条 SSE event，对应后端 "data: {...}" 行
struct InsightSSEEvent: Decodable {
    let type: String
    let scene_id: String?
    let scene_label: String?
    let scene_emoji: String?
    let session_count: Int?
    let token: String?
    let skills: [RadarSkill]?
    let recommendations: [RadarRecommendation]?
    let message: String?
}

/// 单场景洞察结果（流式填充 + 最终数据，可 Codable 存缓存）
struct SceneInsightResult: Codable, Identifiable {
    let sceneId: String
    let sceneLabel: String
    let sceneEmoji: String
    let sessionCount: Int
    var insightText: String
    var skills: [RadarSkill]
    var recommendations: [RadarRecommendation]
    var id: String { sceneId }
}

/// UserDefaults 缓存结构
struct InsightCache: Codable {
    let cacheKey: String    // "startDate_endDate_totalSessions"
    let scenes: [SceneInsightResult]
    let generatedAt: Date
}

// MARK: - API Response Models

struct SkillsRadarResponse: Codable {
    let code: Int
    let message: String?
    let data: SkillsRadarData?
}

struct SkillsRadarData: Codable {
    let scenes: [RadarScene]
    let highlights: [RadarHighlight]
}

struct RadarScene: Codable, Identifiable {
    let scene_id: String
    let scene_label: String
    let scene_emoji: String
    let session_count: Int
    let skills: [RadarSkill]
    let recommendations: [RadarRecommendation]

    var id: String { scene_id }

    /// 轴长比例 (0.2–1.0), 相对同期最大 session_count 归一化，由 ViewModel 计算
    var normalizedValue: Double = 1.0

    enum CodingKeys: String, CodingKey {
        case scene_id, scene_label, scene_emoji, session_count, skills, recommendations
    }
}

/// 高光时刻（跨场景，最多5条）
struct RadarHighlight: Codable, Identifiable {
    let session_id: String
    let session_title: String
    let session_date: String
    let skill_labels: [String]
    let cover_image_url: String?
    let scene_label: String
    let scene_emoji: String
    var id: String { session_id }
}

struct RadarRecommendation: Codable, Identifiable {
    let skill_id: String
    let skill_label: String
    let scene_count: Int
    let reason: String
    var id: String { skill_id }
}

struct RadarSkill: Codable, Identifiable {
    let skill_id: String
    let skill_label: String
    let hit_count: Int
    let level: String?       // "初探" | "练习中" | "熟悉" | "精通" | "驾轻就熟"
    let trend: String?       // "improving" | "stable" | "watch"
    let sparkline: [Int]     // 0/1 per session, max 8 points

    var id: String { skill_id }

    /// 5-pip level indicator count (1–5)
    var pipCount: Int {
        switch hit_count {
        case 0:         return 0
        case 1:         return 1
        case 2:         return 2
        case 3...4:     return 3
        case 5...7:     return 4
        default:        return 5
        }
    }

    /// Axis length ratio for Level 2 radar (0.2–1.0)
    var radarRatio: Double {
        switch hit_count {
        case 0:         return 0.0
        case 1:         return 0.2
        case 2:         return 0.4
        case 3...4:     return 0.6
        case 5...7:     return 0.8
        default:        return 1.0
        }
    }

    var trendColor: Color {
        switch trend {
        case "improving": return Color(hex: "#34D399")
        case "watch":     return Color(hex: "#FB923C")
        default:          return Color.white.opacity(0.4)
        }
    }

    var trendSymbol: String {
        switch trend {
        case "improving": return "↑"
        case "watch":     return "↓"
        default:          return "→"
        }
    }

    var trendLabel: String {
        switch trend {
        case "improving": return "提升中"
        case "watch":     return "可关注"
        default:          return "稳定"
        }
    }
}
