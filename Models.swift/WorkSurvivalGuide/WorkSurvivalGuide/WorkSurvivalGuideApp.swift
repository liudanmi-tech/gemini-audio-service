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

/// ZStack 叠加：ContentView 立即在后台初始化，开屏图覆盖其上
struct SplashCoordinator: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()
            if showSplash {
                SplashScreenView(onFinish: { showSplash = false })
            }
        }
    }
}

struct SplashScreenView: View {
    let onFinish: () -> Void

    private var splashImage: UIImage? {
        if let img = UIImage(named: "LaunchImage") { return img }
        if let img = UIImage(named: "kaiping2") { return img }
        if let path = Bundle.main.path(forResource: "kaiping2", ofType: "png"),
           let img = UIImage(contentsOfFile: path) { return img }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let img = splashImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onFinish()  // 直接消失，无动画
            }
        }
    }
}
