//
//  ProfileViewModel.swift
//  WorkSurvivalGuide
//
//  档案列表 ViewModel
//

import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    static let shared = ProfileViewModel()
    
    @Published var profiles: [Profile] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    private var hasLoaded = false
    private var loadingTask: Task<Void, Never>?
    
    private init() {
        // 私有初始化器，确保单例模式
    }
    
    // 加载档案列表
    func loadProfiles(forceRefresh: Bool = false) {
        // 如果已经有数据且不在加载中，且不是强制刷新，则跳过
        if !forceRefresh && !profiles.isEmpty && !isLoading && hasLoaded {
            print("✅ [ProfileViewModel] 数据已存在，跳过加载")
            return
        }
        
        // 如果正在加载中，取消之前的任务
        if isLoading {
            print("⚠️ [ProfileViewModel] 正在加载中，跳过重复请求")
            loadingTask?.cancel()
        }
        
        isLoading = true
        errorMessage = nil
        
        loadingTask = Task {
            do {
                let response = try await networkManager.getProfilesList()
                
                guard !Task.isCancelled else {
                    print("⚠️ [ProfileViewModel] 加载任务已取消")
                    return
                }
                
                await MainActor.run {
                    self.profiles = response.profiles
                    self.isLoading = false
                    self.hasLoaded = true
                    print("✅ [ProfileViewModel] 成功加载 \(response.profiles.count) 个档案")
                }
            } catch {
                guard !Task.isCancelled else {
                    print("⚠️ [ProfileViewModel] 加载任务已取消")
                    return
                }
                
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("❌ [ProfileViewModel] 加载档案失败: \(error)")
                }
            }
        }
    }
    
    // 创建档案
    func createProfile(_ profile: Profile) async throws {
        let createdProfile = try await networkManager.createProfile(profile)
        await MainActor.run {
            self.profiles.append(createdProfile)
        }
    }
    
    // 更新档案
    func updateProfile(_ profile: Profile) async throws {
        let updatedProfile = try await networkManager.updateProfile(profile)
        await MainActor.run {
            if let index = self.profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
                self.profiles[index] = updatedProfile
            }
        }
    }
    
    // 删除档案
    func deleteProfile(_ profileId: String) async throws {
        try await networkManager.deleteProfile(profileId)
        await MainActor.run {
            self.profiles.removeAll { $0.id == profileId }
        }
    }
}
