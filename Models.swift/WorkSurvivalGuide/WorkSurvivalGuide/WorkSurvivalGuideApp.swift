//
//  WorkSurvivalGuideApp.swift
//  WorkSurvivalGuide
//
//  Created by liudan on 2026/1/8.
//

import SwiftUI

@main
struct WorkSurvivalGuideApp: App {
    @State private var showSplash = true

    init() {
        // 预初始化订阅管理器：App 启动时提前加载 App Store 产品 + 同步订阅状态
        _ = SubscriptionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        Image("LaunchImage")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }
}
