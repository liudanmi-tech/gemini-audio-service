//
//  LoginView.swift
//  WorkSurvivalGuide
//
//  登录页面：Apple Sign In + 邮箱/密码
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {

                        // ── Logo & Title ──
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 64))
                                .foregroundColor(.blue)
                                .padding(.top, 64)

                            Text("Welcome")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)

                            Text("Sign in to continue")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.bottom, 40)

                        VStack(spacing: 16) {

                            // ── Apple Sign In ──
                            SignInWithAppleButton(.signIn) { request in
                                request.requestedScopes = [.fullName, .email]
                            } onCompletion: { result in
                                viewModel.handleAppleSignIn(result: result)
                            }
                            .frame(height: 50)
                            .cornerRadius(10)
                            .disabled(viewModel.isLoading)

                            // ── Divider ──
                            HStack {
                                Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                                Text("or").font(.system(size: 13)).foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 8)
                                Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2))
                            }

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
                                Text("Don't have an account? ")
                                    .foregroundColor(.white.opacity(0.6))
                                + Text("Sign Up")
                                    .foregroundColor(.blue)
                            }
                            .font(.system(size: 14))
                            .padding(.top, 8)
                        }
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)

                        // ── Privacy Policy ──
                        PrivacyFooterView()
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
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
}

// MARK: - Privacy Footer

struct PrivacyFooterView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("By continuing, you agree to our")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
            HStack(spacing: 4) {
                Link("Privacy Policy", destination: URL(string: "https://your-domain.com/privacy")!)
                    .font(.system(size: 12))
                    .foregroundColor(.blue.opacity(0.8))
                Text("and")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Link("Terms of Service", destination: URL(string: "https://your-domain.com/terms")!)
                    .font(.system(size: 12))
                    .foregroundColor(.blue.opacity(0.8))
            }
        }
    }
}
