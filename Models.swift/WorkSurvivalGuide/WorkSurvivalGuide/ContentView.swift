//
//  ContentView.swift
//  WorkSurvivalGuide
//
//  主视图 - 按照Figma设计稿实现
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab: TabItem = .fragments
    @StateObject private var recordingViewModel = RecordingViewModel()
    @State private var showFilePicker = false
    
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
                                    case .skills:
                                        SkillsView()
                                    case .profile:
                                        ProfileListView()
                                    }
                                }
                                
                                // 录音按钮 + 本地上传按钮（只在碎片页面显示）
                                if selectedTab == .fragments {
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            RecordingButtonView(
                                                viewModel: recordingViewModel,
                                                onUploadTap: { showFilePicker = true }
                                            )
                                            .padding(.trailing, 0)
                                            .padding(.bottom, 100) // 位于底部导航栏上方
                                        }
                                    }
                                }
                                
                                // 上传进度悬浮提示（100% 后显示「正在处理，请稍候...」）
                                if recordingViewModel.isUploading {
                                    Color.black.opacity(0.3)
                                        .ignoresSafeArea()
                                    VStack(spacing: 12) {
                                        ProgressView()
                                            .scaleEffect(1.2)
                                        Text(recordingViewModel.uploadPhaseDescription)
                                            .font(.system(size: 15, weight: .medium, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("\(Int(recordingViewModel.uploadProgress * 100))%")
                                            .font(.system(size: 14, weight: .regular, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .padding(24)
                                    .background(Color.black.opacity(0.6))
                                    .cornerRadius(12)
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
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio, .mpeg4Audio, .mp3, .wav],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    recordingViewModel.uploadLocalFile(fileURL: url)
                }
            case .failure(let error):
                print("❌ [ContentView] 选择文件失败: \(error)")
            }
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
