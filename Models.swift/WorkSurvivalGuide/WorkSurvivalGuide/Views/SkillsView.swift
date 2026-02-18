//
//  SkillsView.swift
//  WorkSurvivalGuide
//
//  技能库视图 - 按照Figma设计稿实现
//

import SwiftUI

struct SkillsView: View {
    @ObservedObject private var viewModel = SkillsViewModel.shared
    
    var body: some View {
        ZStack {
            // 背景色已由 ContentView 提供，这里不需要重复设置
            
            VStack(spacing: 0) {
                // Header区域
                SkillsHeaderView()
                
                // 主内容区域
                if viewModel.isLoading && viewModel.skills.isEmpty {
                    Spacer()
                    ProgressView("加载中...")
                        .tint(AppColors.headerText)
                    Spacer()
                } else if viewModel.skills.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondaryText)
                        Text("还没有技能")
                            .font(AppFonts.cardTitle)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 15.99368667602539) { // 根据Figma: gap 15.99px
                            // 提示文字
                            Text("已启用智能编排，手动选择将作为偏好参考。")
                                .font(.system(size: 14, weight: .medium, design: .rounded)) // Nunito 500, 14px
                                .foregroundColor(AppColors.headerText.opacity(0.7)) // rgba(94, 75, 53, 0.7)
                                .padding(.horizontal, 19.992115020751953) // 根据Figma: padding horizontal 19.99px
                                .padding(.top, 0)
                                .padding(.bottom, 0)
                            
                            // 技能列表
                            ForEach(viewModel.skills) { skill in
                                SkillCardView(
                                    skill: skill,
                                    isSelected: viewModel.isSkillSelected(skill.id),
                                    onToggle: {
                                        viewModel.toggleSkill(skill.id)
                                    }
                                )
                                .padding(.horizontal, 19.992115020751953) // 根据Figma: padding horizontal 19.99px
                            }
                        }
                        .padding(.top, 0)
                        .padding(.bottom, 100) // 为底部导航栏留出空间
                    }
                }
            }
        }
        .onAppear {
            // 只在数据为空且不在加载中时才加载
            if viewModel.skills.isEmpty && !viewModel.isLoading {
                viewModel.loadSkills()
            }
        }
    }
}

// Header视图
struct SkillsHeaderView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左侧：标题
            Text("技能库")
                .font(.system(size: 24, weight: .black, design: .rounded)) // Nunito 900, 24px
                .foregroundColor(AppColors.headerText) // #5E4B35
                .tracking(0.6) // letterSpacing 2.5% of 24px = 0.6pt
            
            Spacer()
            
            // 右侧：自动编排按钮
            Button(action: {
                // TODO: 实现自动编排功能
            }) {
                HStack(alignment: .center, spacing: 5.99226188659668) { // 根据Figma: gap 5.99px
                    // 图标
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 14, height: 14)
                    
                    // 文字
                    Text("自动编排")
                        .font(.system(size: 12, weight: .bold, design: .rounded)) // Nunito 700, 12px
                        .foregroundColor(.white) // #FFFFFF
                }
                .padding(.leading, 11.995272636413574) // 根据Figma: padding left 11.99px
                .padding(.trailing, 11.995272636413574) // padding right 11.99px
                .padding(.vertical, 0)
                .frame(height: 29.36) // 根据Figma: height 29.36px
                .background(
                    RoundedRectangle(cornerRadius: 23144300) // 根据Figma: borderRadius 23144300px (极大值，实际为胶囊形状)
                        .fill(Color(hex: "#5E7C8B")) // 根据Figma: #5E7C8B
                        .overlay(
                            RoundedRectangle(cornerRadius: 23144300)
                                .stroke(Color(hex: "#5E7C8B"), lineWidth: 0.69) // strokeWeight 0.69px
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1) // 根据Figma: boxShadow
            }
        }
        .padding(.horizontal, 23.99053192138672) // 根据Figma: padding horizontal 23.99px
        .padding(.vertical, 0)
        .frame(height: 79.98) // 根据Figma: height 79.98px
        .background(Color.black)
    }
}
