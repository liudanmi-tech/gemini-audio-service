//
//  SkillsRadarViewModel.swift
//  WorkSurvivalGuide
//
//  新版技能雷达 ViewModel：请求 /api/v1/skills-radar，管理数据加载
//

import SwiftUI
import Combine

@MainActor
class SkillsRadarViewModel: ObservableObject {
    static let shared = SkillsRadarViewModel()

    @Published var scenes: [RadarScene] = []
    @Published var highlights: [RadarHighlight] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var loadedKey: String? = nil   // "startDate_endDate" cache key

    // MARK: - Load

    func load(startDate: String, endDate: String) async {
        let key = "\(startDate)_\(endDate)"
        if loadedKey == key && !scenes.isEmpty { return }
        isLoading = true
        errorMessage = nil
        do {
            let data = try await NetworkManager.shared.getSkillsRadar(
                startDate: startDate, endDate: endDate
            )
            var normalized = data.scenes
            let maxCount = normalized.map(\.session_count).max() ?? 1
            for i in normalized.indices {
                let ratio = Double(normalized[i].session_count) / Double(maxCount)
                normalized[i].normalizedValue = max(0.25, ratio)
            }
            scenes = normalized
            highlights = data.highlights
            if !normalized.isEmpty {
                loadedKey = key
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Add Recommended Skill

    func markRecommendationAdded(skillId: String) {
        Task {
            do {
                try await NetworkManager.shared.addSkillToPreferences(skillId: skillId)
                loadedKey = nil
            } catch {
                // Silently fail — UI shows "已添加" optimistically
            }
        }
    }

    // MARK: - Reset (call on logout / date range change)

    func reset() {
        scenes = []
        highlights = []
        loadedKey = nil
        isLoading = false
        errorMessage = nil
    }
}
