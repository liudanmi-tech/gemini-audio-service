//
//  BottomNavView.swift
//  WorkSurvivalGuide
//
//  底部导航栏 - 按照Figma设计稿实现
//

import SwiftUI

enum TabItem: String, CaseIterable {
    case fragments = "碎片"
    case skills = "技能"
    case profile = "档案" // 从"我的"改为"档案"
    
    var iconName: String {
        switch self {
        case .fragments:
            return "square.grid.2x2.fill"
        case .skills:
            return "sparkles" // 技能图标
        case .profile:
            return "person.circle.fill" // 档案图标
        }
    }
}

struct BottomNavView: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        ZStack {
            // 毛玻璃背景层
            RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight])
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight])
                        .stroke(AppColors.BottomNav.borderLine, lineWidth: 1)
                )
                .overlay(
                    // 顶部边缘部分亮变：中间亮，向两侧渐隐
                    VStack {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.5),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 2)
                        Spacer()
                    }
                )
            
            // 内容层
            HStack(spacing: 0) {
                ForEach(TabItem.allCases, id: \.self) { tab in
                    BottomNavItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: {
                            selectedTab = tab
                        }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, 23.99) // 根据 Figma: Padding Left 23.99
            .padding(.trailing, 23.99) // 根据 Figma: Padding Right 23.99
            .padding(.top, 0) // 根据 Figma: Padding Top 0
            .padding(.bottom, 0) // 根据 Figma: Padding Bottom 0
        }
        .frame(width: 380.74, height: 79.99) // 根据 Figma: Width 380.74, Height 79.99
        .ignoresSafeArea(edges: .bottom) // 延伸到安全区域底部
    }
}

struct BottomNavItem: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // 图标
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(AppColors.BottomNav.activeIconBg)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(bottomNavEdgeGradient, lineWidth: 1.5)
                                    .frame(width: 40, height: 40)
                            )
                    }
                    Image(systemName: tab.iconName)
                        .font(.system(size: 24))
                        .foregroundColor(isSelected ? AppColors.BottomNav.activeText : AppColors.BottomNav.inactiveText)
                }
                
                // 文字
                Text(tab.rawValue)
                    .font(AppFonts.bottomNav)
                    .foregroundColor(isSelected ? AppColors.BottomNav.activeText : AppColors.BottomNav.inactiveText)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    /// 底部导航图标边缘部分亮变：上下弧亮，左右渐隐
    private var bottomNavEdgeGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color.white.opacity(0.6),
                Color.white.opacity(0.12),
                Color.white.opacity(0.6),
                Color.white.opacity(0.12)
            ],
            center: .center
        )
    }
}

// 注意：cornerRadius扩展已移至ViewExtensions.swift，这里不再重复定义
