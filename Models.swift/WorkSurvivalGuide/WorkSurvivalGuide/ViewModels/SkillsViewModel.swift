//
//  SkillsViewModel.swift
//  WorkSurvivalGuide
//
//  技能列表 ViewModel
//

import Foundation
import Combine

class SkillsViewModel: ObservableObject {
    @Published var skills: [SkillItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSkills: Set<String> = [] // 选中的技能ID集合
    
    private let networkManager = NetworkManager.shared
    
    // 加载技能列表
    func loadSkills(category: String? = nil) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await networkManager.getSkillsList(category: category, enabled: true)
                await MainActor.run {
                    self.skills = response.skills
                    self.isLoading = false
                    print("✅ [SkillsViewModel] 成功加载 \(response.skills.count) 个技能")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("❌ [SkillsViewModel] 加载技能失败: \(error)")
                }
            }
        }
    }
    
    // 刷新技能列表
    func refreshSkills() {
        loadSkills()
    }
    
    // 切换技能选中状态
    func toggleSkill(_ skillId: String) {
        if selectedSkills.contains(skillId) {
            selectedSkills.remove(skillId)
        } else {
            selectedSkills.insert(skillId)
        }
    }
    
    // 检查技能是否被选中
    func isSkillSelected(_ skillId: String) -> Bool {
        return selectedSkills.contains(skillId)
    }
}
