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
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = UIImage(named: "kaiping2.png")
                ?? UIImage(named: "kaiping2")
                ?? UIImage(named: "LaunchImage") {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            let names = ["kaiping2.png", "kaiping2", "LaunchImage"]
            for n in names {
                print("[Splash] UIImage(named:\"\(n)\") = \(UIImage(named: n) != nil ? "✅" : "❌")")
            }
            if let path = Bundle.main.path(forResource: "kaiping2", ofType: "png") {
                print("[Splash] Bundle path ✅: \(path)")
            } else {
                print("[Splash] Bundle path ❌ not found")
            }
        }
    }
}
