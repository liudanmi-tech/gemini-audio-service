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
        .padding(.horizontal, 24)
        .padding(.vertical, 0)
        .frame(height: 80)
        .background(AppColors.background)
        .overlay(
            Rectangle()
                .frame(height: 1.38)
                .foregroundColor(AppColors.border)
                .offset(y: -40),
            alignment: .top
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: -4)
        .clipShape(RoundedCornerShape(radius: 24, corners: [.topLeft, .topRight]))
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
