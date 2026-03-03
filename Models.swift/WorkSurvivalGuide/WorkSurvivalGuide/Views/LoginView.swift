//
//  LoginView.swift
//  WorkSurvivalGuide
//
//  登录页面
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    @State private var phoneText: String = ""
    @State private var codeText: String = ""
    
    enum Field {
        case phone
        case code
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Logo和标题区域
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                        .padding(.top, 60)
                    
                    Text("Welcome")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Sign in to continue")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)
                
                // 输入区域
                VStack(spacing: 20) {
                    // 手机号输入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Phone Number")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))

                        TextField("Enter your phone number", text: $phoneText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .phone)
                            .onChange(of: phoneText) { newValue in
                                // 限制只能输入数字，最多11位
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue || filtered.count > 11 {
                                    phoneText = String(filtered.prefix(11))
                                }
                                viewModel.phone = phoneText
                            }
                            .onChange(of: focusedField) { newValue in
                                if newValue != .phone {
                                    viewModel.phone = phoneText
                                }
                            }
                    }
                    
                    // 验证码输入
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Verification Code")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()
                            
                            Button(action: {
                                viewModel.sendCode()
                            }) {
                                if viewModel.countdown > 0 {
                                    Text("\(viewModel.countdown)s to resend")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Send Code")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                            }
                            .disabled(!viewModel.canSendCode || viewModel.isLoading)
                        }
                        
                        TextField("Enter 6-digit code", text: $codeText)
                            .keyboardType(.numberPad)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .code)
                            .onChange(of: codeText) { newValue in
                                // 限制只能输入数字，最多6位
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue || filtered.count > 6 {
                                    codeText = String(filtered.prefix(6))
                                }
                                viewModel.code = codeText
                            }
                            .onChange(of: focusedField) { newValue in
                                if newValue != .code {
                                    viewModel.code = codeText
                                }
                            }
                    }
                    
                    // 登录按钮
                    Button(action: {
                        focusedField = nil
                        viewModel.login()
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
                            phoneText.count == 11 && codeText.count == 6 && !viewModel.isLoading
                            ? Color.blue
                            : Color.gray.opacity(0.3)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(phoneText.count != 11 || codeText.count != 6 || viewModel.isLoading)
                    .padding(.top, 10)
                    
                    // 注册入口
                    NavigationLink("Don't have an account? Sign up", destination: RegisterView())
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // 提示信息
                VStack(spacing: 4) {
                    Text("Dev code: 123456")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Phone format: 11 digits")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
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
