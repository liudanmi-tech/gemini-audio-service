//
//  LoginView.swift
//  WorkSurvivalGuide
//
//  登录：Landing 页（苹果登录为主 CTA）+ 邮箱表单（次级入口）
//

import SwiftUI
import AuthenticationServices

// MARK: - Landing Page

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {

                    Spacer()

                    // ── Logo + Tagline ──
                    VStack(spacing: 14) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 72))
                            .foregroundColor(.blue)

                        Text("Work Survival Guide")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)

                        Text("Your personal AI work coach")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    // ── Auth Buttons ──
                    VStack(spacing: 12) {

                        // Apple Sign In — 主 CTA
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            viewModel.handleAppleSignIn(result: result)
                        }
                        .frame(height: 50)
                        .cornerRadius(10)
                        .disabled(viewModel.isLoading)

                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }

                        // Continue with phone — 测试用按钮
                        NavigationLink(destination: PhoneSignInView()) {
                            HStack(spacing: 8) {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 15))
                                Text("Continue with phone")
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(viewModel.isLoading)

                        // Continue with email — 次级文字链接
                        NavigationLink(destination: EmailSignInView()) {
                            Text("Continue with email")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.55))
                                .underline()
                        }
                        .padding(.top, 2)
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 32)

                    // ── Privacy ──
                    PrivacyFooterView()
                        .padding(.top, 28)
                        .padding(.bottom, 36)
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }
}

// MARK: - Email Sign In (次级入口页)

private struct EmailSignInView: View {
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // ── Title ──
                    VStack(spacing: 8) {
                        Text("Sign In")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("Enter your email and password")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 32)

                    // ── Email ──
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Email")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        TextField("Enter your email", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .email)
                    }

                    // ── Password ──
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        SecureField("Password (8+ characters)", text: $viewModel.password)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .password)
                    }

                    // ── Sign In Button ──
                    Button(action: {
                        focusedField = nil
                        viewModel.emailSignIn()
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            !viewModel.email.isEmpty && viewModel.password.count >= 8 && !viewModel.isLoading
                            ? Color.blue : Color.gray.opacity(0.3)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.email.isEmpty || viewModel.password.count < 8 || viewModel.isLoading)
                    .padding(.top, 4)

                    // ── Register Link ──
                    NavigationLink(destination: RegisterView()) {
                        (Text("Don't have an account? ")
                            .foregroundColor(.white.opacity(0.5))
                        + Text("Sign Up")
                            .foregroundColor(.blue))
                        .font(.system(size: 14))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
    }
}

// MARK: - Phone Sign In (测试用)

private struct PhoneSignInView: View {
    @State private var phone = ""
    @State private var code = ""
    @State private var isLoading = false
    @State private var countdown = 0
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var focusedField: Field?

    enum Field { case phone, code }

    private var canSendCode: Bool { phone.count == 11 && countdown == 0 && !isLoading }
    private var canSignIn: Bool { phone.count == 11 && code.count == 6 && !isLoading }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    VStack(spacing: 8) {
                        Text("Phone Sign In")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        Text("Enter your phone number")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 32)

                    // ── Phone ──
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Phone Number")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        TextField("11-digit phone number", text: $phone)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .phone)
                            .onChange(of: phone) { v in
                                let f = v.filter { $0.isNumber }
                                phone = String((f != v ? f : v).prefix(11))
                            }
                    }

                    // ── Code ──
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Verification Code")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                            Button(action: sendCode) {
                                Text(countdown > 0 ? "\(countdown)s" : "Send Code")
                                    .font(.system(size: 14))
                                    .foregroundColor(canSendCode ? .blue : .gray)
                            }
                            .disabled(!canSendCode)
                        }
                        TextField("6-digit code", text: $code)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .code)
                            .onChange(of: code) { v in
                                let f = v.filter { $0.isNumber }
                                code = String((f != v ? f : v).prefix(6))
                            }
                    }

                    // ── Sign In Button ──
                    Button(action: {
                        focusedField = nil
                        signIn()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Sign In").font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSignIn ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canSignIn)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationTitle("Phone Sign In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func sendCode() {
        Task {
            isLoading = true
            do {
                _ = try await AuthService.shared.sendVerificationCode(phone: phone)
                isLoading = false
                startCountdown()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func signIn() {
        Task {
            isLoading = true
            do {
                _ = try await AuthService.shared.login(phone: phone, code: code)
                let userInfo = try await AuthService.shared.getCurrentUser()
                isLoading = false
                AuthManager.shared.loginSuccess(userInfo: userInfo)
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func startCountdown() {
        countdown = 60
        Task {
            while countdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                countdown -= 1
            }
        }
    }
}

// MARK: - Privacy Footer

struct PrivacyFooterView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree to our")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.35))
            HStack(spacing: 4) {
                Link("Privacy Policy", destination: URL(string: "https://your-domain.com/privacy")!)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text("and")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
                Link("Terms of Service", destination: URL(string: "https://your-domain.com/terms")!)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}
