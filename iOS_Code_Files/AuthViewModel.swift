//
//  AuthViewModel.swift
//  WorkSurvivalGuide
//
//  登录/注册 ViewModel：支持邮箱+密码、Apple Sign In
//

import Foundation
import AuthenticationServices

@MainActor
class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Email Sign In (login + auto-register)

    func emailSignIn() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            showAuthError("Please enter your email address")
            return
        }
        guard password.count >= 8 else {
            showAuthError("Password must be at least 8 characters")
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await AuthService.shared.emailLogin(email: trimmedEmail, password: password)
                let userInfo = try await AuthService.shared.getCurrentUser()
                isLoading = false
                AuthManager.shared.loginSuccess(userInfo: userInfo)
            } catch {
                isLoading = false
                showAuthError(error.localizedDescription)
            }
        }
    }

    // MARK: - Email Register (explicit register with confirm password)

    func emailRegister() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            showAuthError("Please enter your email address")
            return
        }
        guard password.count >= 8 else {
            showAuthError("Password must be at least 8 characters")
            return
        }
        guard password == confirmPassword else {
            showAuthError("Passwords do not match")
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                _ = try await AuthService.shared.emailLogin(email: trimmedEmail, password: password)
                let userInfo = try await AuthService.shared.getCurrentUser()
                isLoading = false
                AuthManager.shared.loginSuccess(userInfo: userInfo)
            } catch {
                isLoading = false
                showAuthError(error.localizedDescription)
            }
        }
    }

    // MARK: - Apple Sign In

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8),
                  let codeData = credential.authorizationCode,
                  let authCode = String(data: codeData, encoding: .utf8) else {
                showAuthError("Apple Sign In failed: missing credentials")
                return
            }

            let fullName: String? = {
                guard let name = credential.fullName else { return nil }
                let parts = [name.givenName, name.familyName].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }()

            isLoading = true
            errorMessage = nil

            Task {
                do {
                    _ = try await AuthService.shared.appleLogin(
                        identityToken: identityToken,
                        authCode: authCode,
                        fullName: fullName
                    )
                    let userInfo = try await AuthService.shared.getCurrentUser()
                    isLoading = false
                    AuthManager.shared.loginSuccess(userInfo: userInfo)
                } catch {
                    isLoading = false
                    showAuthError(error.localizedDescription)
                }
            }

        case .failure(let error):
            // 用户主动取消不显示错误
            let nsErr = error as NSError
            if nsErr.code != ASAuthorizationError.canceled.rawValue {
                showAuthError("Apple Sign In failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func showAuthError(_ message: String) {
        errorMessage = message
        showError = true
    }
}
