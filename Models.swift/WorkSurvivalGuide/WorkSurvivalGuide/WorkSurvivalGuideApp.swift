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
        // 预初始化订阅管理器：App 启动时提前加载 App Store 产品 + 同步订阅状态
        _ = SubscriptionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
