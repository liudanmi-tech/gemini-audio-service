//
//  ContentView.swift
//  WorkSurvivalGuide
//
//  主视图 - 按照Figma设计稿实现
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: TabItem = .fragments
    @StateObject private var recordingViewModel = RecordingViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 主内容区域
                    ZStack {
                        // 根据选中的Tab显示不同内容
                        Group {
                            switch selectedTab {
                            case .fragments:
                                TaskListView()
                            case .status:
                                StatusView()
                            case .mine:
                                MineView()
                            }
                        }
                        
                        // 录音按钮（只在碎片页面显示）
                        if selectedTab == .fragments {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    RecordingButtonView(viewModel: recordingViewModel)
                                        .padding(.trailing, 0)
                                        .padding(.bottom, 100) // 位于底部导航栏上方
                                }
                            }
                        }
                    }
                    
                    // 底部导航栏
                    BottomNavView(selectedTab: $selectedTab)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// 状态视图（占位）
struct StatusView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("状态")
                .font(AppFonts.cardTitle)
                .foregroundColor(AppColors.primaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

// 我的视图（占位）
struct MineView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("我的")
                .font(AppFonts.cardTitle)
                .foregroundColor(AppColors.primaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background)
    }
}

#Preview {
    ContentView()
}
