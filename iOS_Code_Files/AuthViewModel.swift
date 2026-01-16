//
//  AuthViewModel.swift
//  WorkSurvivalGuide
//
//  登录页面ViewModel
//

import Foundation
import Combine

class AuthViewModel: ObservableObject {
    @Published var phone: String = ""
    @Published var code: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var countdown: Int = 0
    @Published var canSendCode: Bool = true
    
    private var countdownTimer: Timer?
    
    // 发送验证码
    func sendCode() {
        guard !phone.isEmpty, phone.count == 11, phone.allSatisfy({ $0.isNumber }) else {
            errorMessage = "请输入正确的手机号"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await AuthService.shared.sendVerificationCode(phone: phone)
                await MainActor.run {
                    self.isLoading = false
                    // 开发阶段显示验证码
                    if let code = response.code {
                        print("📱 验证码: \(code)")
                    }
                    self.startCountdown()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    // 登录
    func login() {
        guard !phone.isEmpty, phone.count == 11 else {
            errorMessage = "请输入正确的手机号"
            showError = true
            return
        }
        
        guard !code.isEmpty, code.count == 6 else {
            errorMessage = "请输入6位验证码"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await AuthService.shared.login(phone: phone, code: code)
                // 获取用户信息
                let userInfo = try await AuthService.shared.getCurrentUser()
                await MainActor.run {
                    self.isLoading = false
                    AuthManager.shared.loginSuccess(userInfo: userInfo)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    }
    
    // 开始倒计时
    private func startCountdown() {
        countdown = 60
        canSendCode = false
        
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                self.canSendCode = true
                self.countdownTimer?.invalidate()
            }
        }
    }
    
    deinit {
        countdownTimer?.invalidate()
    }
}
