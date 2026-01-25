//
//  SkillsViewModel.swift
//  WorkSurvivalGuide
//
//  技能列表 ViewModel
//

import Foundation
import Combine

class SkillsViewModel: ObservableObject {
    static let shared = SkillsViewModel()
    
    @Published var skills: [SkillItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedSkills: Set<String> = [] // 选中的技能ID集合
    
    private let networkManager = NetworkManager.shared
    private var hasLoaded = false // 记录是否已经加载过数据
    private var loadingTask: Task<Void, Never>? // 当前加载任务，用于取消重复请求
    
    private init() {
        // 私有初始化器，确保单例模式
    }
    
    // 加载技能列表
    func loadSkills(category: String? = nil, forceRefresh: Bool = false) {
        // 如果已经有数据且不在加载中，且不是强制刷新，则跳过
        if !forceRefresh && !skills.isEmpty && !isLoading && hasLoaded {
            print("✅ [SkillsViewModel] 数据已存在，跳过加载")
            return
        }
        
        // 如果正在加载中，取消之前的任务
        if isLoading {
            print("⚠️ [SkillsViewModel] 正在加载中，跳过重复请求")
            loadingTask?.cancel()
        }
        
        isLoading = true
        errorMessage = nil
        
        loadingTask = Task {
            do {
                let response = try await networkManager.getSkillsList(category: category, enabled: true)
                
                // 检查任务是否被取消
                guard !Task.isCancelled else {
                    print("⚠️ [SkillsViewModel] 加载任务已取消")
                    return
                }
                
                await MainActor.run {
                    self.skills = response.skills
                    self.isLoading = false
                    self.hasLoaded = true
                    print("✅ [SkillsViewModel] 成功加载 \(response.skills.count) 个技能")
                }
            } catch {
                // 检查任务是否被取消
                guard !Task.isCancelled else {
                    print("⚠️ [SkillsViewModel] 加载任务已取消")
                    return
                }
                
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("❌ [SkillsViewModel] 加载技能失败: \(error)")
                }
            }
        }
    }
    
    // 刷新技能列表（强制刷新）
    func refreshSkills() {
        loadSkills(forceRefresh: true)
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
