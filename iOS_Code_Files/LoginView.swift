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
    
    enum Field {
        case phone
        case code
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo和标题区域
            VStack(spacing: 16) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .padding(.top, 60)
                
                Text("欢迎使用")
                    .font(.system(size: 28, weight: .bold))
                
                Text("请登录以继续")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
            
            // 输入区域
            VStack(spacing: 20) {
                // 手机号输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("手机号")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("请输入11位手机号", text: $viewModel.phone)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .phone)
                        .onChange(of: viewModel.phone) { newValue in
                            // 限制只能输入数字，最多11位
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count <= 11 {
                                viewModel.phone = filtered
                            } else {
                                viewModel.phone = String(filtered.prefix(11))
                            }
                        }
                }
                
                // 验证码输入
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("验证码")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.sendCode()
                        }) {
                            if viewModel.countdown > 0 {
                                Text("\(viewModel.countdown)秒后重试")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("发送验证码")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                        }
                        .disabled(!viewModel.canSendCode || viewModel.isLoading)
                    }
                    
                    TextField("请输入6位验证码", text: $viewModel.code)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .code)
                        .onChange(of: viewModel.code) { newValue in
                            // 限制只能输入数字，最多6位
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count <= 6 {
                                viewModel.code = filtered
                            } else {
                                viewModel.code = String(filtered.prefix(6))
                            }
                        }
                }
                
                // 登录按钮
                Button(action: {
                    viewModel.login()
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("登录")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        viewModel.phone.count == 11 && viewModel.code.count == 6 && !viewModel.isLoading
                        ? Color.blue
                        : Color.gray.opacity(0.3)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.phone.count != 11 || viewModel.code.count != 6 || viewModel.isLoading)
                .padding(.top, 10)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 提示信息
            VStack(spacing: 4) {
                Text("开发阶段验证码: 123456")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text("手机号格式: 11位数字")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 30)
        }
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }
}
