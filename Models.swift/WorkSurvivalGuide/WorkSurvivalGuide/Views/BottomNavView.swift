//
//  BottomNavView.swift
//  WorkSurvivalGuide
//
//  底部导航栏 - 按照Figma设计稿实现
//

import SwiftUI

enum TabItem: String, CaseIterable {
    case fragments = "碎片"
    case status = "状态"
    case mine = "我的"
    
    var iconName: String {
        switch self {
        case .fragments:
            return "square.grid.2x2.fill"
        case .status:
            return "chart.bar.fill"
        case .mine:
            return "person.fill"
        }
    }
}

struct BottomNavView: View {
    @Binding var selectedTab: TabItem
    
    var body: some View {
        ZStack {
            // 背景层
            Color(hex: "#F2E6D6") // 根据要求：填充色值 #F2E6D6
                .clipShape(RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight]))
                .overlay(
                    // 顶部边缘线（Stroke）
                    RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight])
                        .stroke(AppColors.BottomNav.borderLine, lineWidth: 1.38) // 根据 Figma: Stroke weight 1.38, color #8FA5B0
                )
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: -4) // Drop shadow 效果
            
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
}

// 注意：cornerRadius扩展已移至ViewExtensions.swift，这里不再重复定义
