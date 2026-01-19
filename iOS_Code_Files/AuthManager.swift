//
//  AuthManager.swift
//  WorkSurvivalGuide
//
//  认证状态管理器
//

import Foundation
import Combine

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
                    logout()
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
        print("🔐 [AuthManager] ========== 开始执行登出操作 ==========")
        print("🔐 [AuthManager] 当前线程: \(Thread.isMainThread ? "主线程" : "后台线程")")
        print("🔐 [AuthManager] 当前 isLoggedIn 状态: \(isLoggedIn)")
        
        // 清除 Keychain 中的 token
        AuthService.shared.logout()
        
        // 确保在主线程上更新状态
        if Thread.isMainThread {
            isLoggedIn = false
            currentUser = nil
            print("🔐 [AuthManager] ✅ 已在主线程更新状态: isLoggedIn = \(isLoggedIn)")
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.isLoggedIn = false
                self?.currentUser = nil
                print("🔐 [AuthManager] ✅ 已在主线程更新状态: isLoggedIn = \(self?.isLoggedIn ?? false)")
            }
        }
        
        print("🔐 [AuthManager] ========== 登出操作完成 ==========")
    }
}
