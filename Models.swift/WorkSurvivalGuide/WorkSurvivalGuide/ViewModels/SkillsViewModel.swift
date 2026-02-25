//
//  SkillsViewModel.swift
//  WorkSurvivalGuide
//

import Foundation
import Combine

class SkillsViewModel: ObservableObject {
    static let shared = SkillsViewModel()

    @Published var categories: [SkillCategory] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSkillForDetail: SkillCatalogItem?

    @Published var skills: [SkillItem] = []
    @Published var selectedSkills: Set<String> = []

    private let networkManager = NetworkManager.shared
    private var hasLoaded = false
    private var loadingTask: Task<Void, Never>?
    private var syncTask: Task<Void, Never>?

    private init() {}

    // MARK: - Catalog

    func loadCatalog(forceRefresh: Bool = false) {
        if !forceRefresh && !categories.isEmpty && !isLoading && hasLoaded {
            return
        }
        loadingTask?.cancel()
        isLoading = true
        errorMessage = nil

        loadingTask = Task {
            do {
                let data = try await networkManager.getSkillsCatalog()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.categories = data.categories
                    self.rebuildSelectedSkills()
                    self.isLoading = false
                    self.hasLoaded = true
                    self.errorMessage = nil
                    print("✅ [SkillsVM] 加载成功: \(data.categories.count) 个分类, 共 \(data.categories.reduce(0) { $0 + $1.skills.count }) 个技能")
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.errorMessage = "\(error.localizedDescription)"
                    self.isLoading = false
                    print("❌ [SkillsVM] 加载失败: \(error)")
                }
            }
        }
    }

    func refreshCatalog() {
        loadCatalog(forceRefresh: true)
    }

    // MARK: - Selection

    func toggleSkill(_ skillId: String) {
        for ci in categories.indices {
            for si in categories[ci].skills.indices {
                if categories[ci].skills[si].skillId == skillId {
                    categories[ci].skills[si].selected.toggle()
                }
            }
        }
        rebuildSelectedSkills()
        syncPreferencesToServer()
    }

    func isSkillSelected(_ skillId: String) -> Bool {
        selectedSkills.contains(skillId)
    }

    func showDetail(_ skill: SkillCatalogItem) {
        selectedSkillForDetail = skill
    }

    // MARK: - Private

    private func rebuildSelectedSkills() {
        var set = Set<String>()
        for cat in categories {
            for skill in cat.skills where skill.selected {
                set.insert(skill.skillId)
            }
        }
        selectedSkills = set
    }

    private func syncPreferencesToServer() {
        syncTask?.cancel()
        let selected = Array(selectedSkills)
        syncTask = Task {
            do {
                try await networkManager.updateSkillPreferences(selectedSkills: selected)
            } catch {
                print("❌ [SkillsVM] 同步偏好失败: \(error)")
            }
        }
    }

    // MARK: - Legacy

    func loadSkills(category: String? = nil, forceRefresh: Bool = false) {
        loadCatalog(forceRefresh: forceRefresh)
    }

    func refreshSkills() {
        refreshCatalog()
    }
}
