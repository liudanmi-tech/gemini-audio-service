//
//  TextInputView.swift
//  WorkSurvivalGuide
//
//  文字输入视图 - 用户输入今天发生的事，提交后生图并做技能分析
//

import SwiftUI

struct TextInputView: View {
    @StateObject private var viewModel = TextInputViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 提示文字
                    HStack {
                        Text("描述今天发生的事，涉及到的人名会自动匹配档案，生成专属场景图")
                            .font(AppFonts.time)
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                        Spacer()
                    }

                    // 文字输入框
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cardBackground)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        TextEditor(text: $viewModel.inputText)
                            .font(AppFonts.cardTitle)
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            .frame(minHeight: 200, maxHeight: 360)
                            .scrollContentBackground(.hidden)
                            .disabled(viewModel.isSubmitting)

                        if viewModel.inputText.isEmpty {
                            Text("今天我和张经理开会讨论了 Q1 预算，下午又找了李总监...")
                                .font(AppFonts.cardTitle)
                                .foregroundColor(AppColors.secondaryText.opacity(0.6))
                                .padding(.horizontal, 28)
                                .padding(.top, 24)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.top, 0)

                    // 字数统计
                    HStack {
                        Spacer()
                        Text("\(viewModel.inputText.count) 字")
                            .font(AppFonts.time)
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.trailing, 24)
                            .padding(.top, 6)
                    }

                    Spacer()

                    // 提交按钮
                    Button(action: {
                        viewModel.submit {
                            dismiss()
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(viewModel.canSubmit ? Color.blue : Color.gray.opacity(0.4))
                                .frame(height: 52)

                            if viewModel.isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("生成场景图 & 技能分析")
                                    .font(AppFonts.cardTitle)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                    // 错误提示
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(AppFonts.time)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("文字记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                        .foregroundColor(AppColors.headerText)
                }
            }
        }
    }
}
