//
//  AppConfig.swift
//  WorkSurvivalGuide
//
//  应用配置（环境切换）
//

import Foundation

enum AppEnvironment {
    case development  // 开发环境（使用 Mock 数据）
    case production   // 生产环境（使用真实 API）
}

class AppConfig {
    static let shared = AppConfig()
    
    // 当前环境（可以通过 UserDefaults 或编译配置切换）
    var currentEnvironment: AppEnvironment {
        // 方法 1: 通过 UserDefaults 切换（运行时切换）
        if let useMock = UserDefaults.standard.object(forKey: "use_mock_data") as? Bool {
            return useMock ? .development : .production
        }
        
        // 方法 2: 通过编译配置切换（编译时切换）
        // 默认使用真实 API（生产环境）
        #if DEBUG
        // DEBUG 模式下，默认使用真实 API，可以通过 UserDefaults 切换
        return .production
        #else
        return .production
        #endif
    }
    
    // 是否使用 Mock 数据
    var useMockData: Bool {
        return currentEnvironment == .development
    }
    
    private init() {}
    
    // 切换环境（用于测试）
    func setUseMockData(_ useMock: Bool) {
        UserDefaults.standard.set(useMock, forKey: "use_mock_data")
    }
}

