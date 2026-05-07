//
//  WorkSurvivalGuideApp.swift
//  WorkSurvivalGuide
//
//  Created by liudan on 2026/1/8.
//

import SwiftUI

@main
struct WorkSurvivalGuideApp: App {
    init() {
        _ = SubscriptionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            SplashCoordinator()
        }
    }
}

/// 启动协调器：先展示开屏图，完成后切换到 ContentView
struct SplashCoordinator: View {
    @State private var splashDone = false

    var body: some View {
        if splashDone {
            ContentView()
        } else {
            SplashScreenView(onFinish: { splashDone = true })
        }
    }
}

struct SplashScreenView: View {
    let onFinish: () -> Void

    var body: some View {
        Color.red
            .ignoresSafeArea()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onFinish()
                }
            }
    }
}
