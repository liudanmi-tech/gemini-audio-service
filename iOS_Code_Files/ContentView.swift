import SwiftUI

struct ContentView: View {
    @ObservedObject private var authManager = AuthManager.shared
    @State private var selectedTab: TabItem = .fragments
    @StateObject private var recordingViewModel = RecordingViewModel()
    
    var body: some View {
        Group {
            if authManager.isLoggedIn {
                // 调试日志
                let _ = print("🖥️ [ContentView] 显示主界面，isLoggedIn = \(authManager.isLoggedIn)")
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
            } else {
                // 调试日志
                let _ = print("🖥️ [ContentView] 显示登录页面，isLoggedIn = \(authManager.isLoggedIn)")
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
