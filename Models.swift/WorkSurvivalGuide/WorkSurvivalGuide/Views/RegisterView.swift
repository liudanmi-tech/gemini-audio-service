//
//  RegisterView.swift
//  WorkSurvivalGuide
//
//  注册页面：Apple Sign In + 邮箱/密码
//

import SwiftUI
import AuthenticationServices

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    enum Field { case email, password, confirm }

    private var canRegister: Bool {
        !viewModel.email.isEmpty &&
        viewModel.password.count >= 8 &&
        viewModel.password == viewModel.confirmPassword &&
        !viewModel.isLoading
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Logo & Title ──
                    VStack(spacing: 16) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)
                            .padding(.top, 64)

                        Text("Create Account")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)

                        Text("Join to start your journey")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 40)

                    VStack(spacing: 16) {

                        // ── Apple Sign Up ──
                        SignInWithAppleButton(.signUp) { request in
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
                            SecureField("8+ characters", text: $viewModel.password)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .password)
                        }

                        // ── Confirm Password ──
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            SecureField("Re-enter password", text: $viewModel.confirmPassword)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .confirm)
                            if !viewModel.confirmPassword.isEmpty && viewModel.password != viewModel.confirmPassword {
                                Text("Passwords do not match")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                        }

                        // ── Create Account Button ──
                        Button(action: {
                            focusedField = nil
                            viewModel.emailRegister()
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create Account")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canRegister ? Color.blue : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(!canRegister)
                        .padding(.top, 4)

                        // ── Back to Sign In ──
                        Button(action: { dismiss() }) {
                            (Text("Already have an account? ")
                                .foregroundColor(.white.opacity(0.6))
                            + Text("Sign In")
                                .foregroundColor(.blue))
                            .font(.system(size: 14))
                        }
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
