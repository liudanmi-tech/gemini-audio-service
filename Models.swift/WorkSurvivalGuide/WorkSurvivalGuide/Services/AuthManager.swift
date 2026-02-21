//
//  AuthManager.swift
//  WorkSurvivalGuide
//
//  认证状态管理器
//

import Foundation
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserInfo?
    
    private init() {
        checkLoginStatus()
    }
    
    // 检查登录状态
    func checkLoginStatus() {
        isLoggedIn = KeychainManager.shared.isLoggedIn()
        if isLoggedIn {
            loadUserInfo()
        }
    }
    
    // 加载用户信息
    func loadUserInfo() {
        Task {
            do {
                let userInfo = try await AuthService.shared.getCurrentUser()
                await MainActor.run {
                    self.currentUser = userInfo
                }
            } catch {
                // Token可能已过期，清除登录状态
                if (error as NSError).code == 401 {
                    await MainActor.run { self.logout() }
                }
            }
        }
    }
    
    // 登录成功
    func loginSuccess(userInfo: UserInfo) {
        isLoggedIn = true
        currentUser = userInfo
    }
    
    // 登出
    func logout() {
        AuthService.shared.logout()
        isLoggedIn = false
        currentUser = nil
    }
}
