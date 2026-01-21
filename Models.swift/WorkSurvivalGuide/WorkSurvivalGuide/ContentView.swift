//
//  ContentView.swift
//  WorkSurvivalGuide
//
//  主视图 - 按照Figma设计稿实现
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab: TabItem = .fragments
    @StateObject private var recordingViewModel = RecordingViewModel()
    
    var body: some View {
        Group {
            if authManager.isLoggedIn {
                NavigationStack {
                    ZStack {
                        // 背景色（底层）
                        AppColors.background
                            .ignoresSafeArea()
                        
                        // 信纸网格底纹（在背景色上方，但不覆盖底部导航栏）
                        PaperGridBackground()
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
                        }
                        
                        // 底部导航栏（最顶层，不被网格覆盖）
                        VStack {
                            Spacer()
                            BottomNavView(selectedTab: $selectedTab)
                        }
                    }
                    .ignoresSafeArea(edges: .bottom) // 整个 ZStack 延伸到安全区域底部
                    .navigationBarHidden(true)
                }
            } else {
                LoginView()
            }
        }
        .onAppear {
            authManager.checkLoginStatus()
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
