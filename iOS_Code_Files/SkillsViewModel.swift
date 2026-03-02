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

    /// 编排模式：false = 自动编排（默认），true = 手动编排
    @Published var isManualMode: Bool = UserDefaults.standard.bool(forKey: "skillManualMode") {
        didSet {
            UserDefaults.standard.set(isManualMode, forKey: "skillManualMode")
        }
    }

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
                // 先加载 catalog（含 selected 状态）
                let data = try await networkManager.getSkillsCatalog()
                // 同时拉取模式设置
                let prefs = try? await networkManager.getSkillPreferences()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.categories = data.categories
                    self.rebuildSelectedSkills()
                    if let mode = prefs?.isManualMode {
                        self.isManualMode = mode
                        UserDefaults.standard.set(mode, forKey: "skillManualMode")
                    }
                    self.isLoading = false
                    self.hasLoaded = true
                    self.errorMessage = nil
                    print("✅ [SkillsVM] 加载成功: \(data.categories.count) 个分类, 共 \(data.categories.reduce(0) { $0 + $1.skills.count }) 个技能, 手动模式=\(self.isManualMode)")
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

    // MARK: - Mode Toggle

    func toggleMode() {
        isManualMode.toggle()
        syncPreferencesToServer()
    }

    /// 手动模式下：已选技能排在前面；自动模式下直接返回原顺序
    var sortedCategories: [SkillCategory] {
        guard isManualMode else { return categories }
        return categories.map { cat in
            var c = cat
            c.skills = cat.skills.sorted { a, b in
                switch (a.selected, b.selected) {
                case (true, false): return true
                case (false, true): return false
                default: return false
                }
            }
            return c
        }
    }

    /// 手动模式下已勾选的技能数
    var manualSelectedCount: Int {
        selectedSkills.count
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
        let manual = isManualMode
        syncTask = Task {
            do {
                try await networkManager.updateSkillPreferences(selectedSkills: selected, isManualMode: manual)
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
