//
//  RegisterView.swift
//  WorkSurvivalGuide
//
//  注册页面 - 手机号+验证码注册，成功后自动登录
//

import SwiftUI

struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @FocusState private var focusedField: Field?
    @State private var phoneText: String = ""
    @State private var codeText: String = ""
    
    enum Field {
        case phone
        case code
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题区域
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 60)
                
                Text("Create Account")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Enter your phone number to register")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
            
            // 输入区域
            VStack(spacing: 20) {
                // 手机号输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Enter your phone number", text: $phoneText)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .phone)
                        .onChange(of: phoneText) { newValue in
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
                            .foregroundColor(.secondary)
                        
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
                
                // 注册按钮（复用 login API，后端自动创建用户）
                Button(action: {
                    focusedField = nil
                    viewModel.login()
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Sign Up")
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
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 提示信息
            VStack(spacing: 4) {
                Text("Dev code: 123456")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("Phone format: 11 digits")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 30)
        }
        .navigationBarHidden(false)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
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
