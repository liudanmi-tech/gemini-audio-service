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
    
    // 方案二：北京只读 API 双域路由（中国用户提速）
    // 为 true 时：读接口走北京，写接口走新加坡
    var useBeijingRead: Bool {
        if let v = UserDefaults.standard.object(forKey: "use_beijing_read") as? Bool {
            return v
        }
        #if DEBUG
        return true   // 开发默认开启北京读
        #else
        return true   // 生产默认开启
        #endif
    }
    
    /// 北京只读节点（录音列表、详情、策略、技能、档案、图片等读接口）
    var readBaseURL: String { "http://123.57.29.111:8000/api/v1" }
    
    /// 新加坡主节点（上传、登录、写操作、策略生成）
    var writeBaseURL: String { "http://47.79.254.213/api/v1" }
    
    private init() {}
    
    // 切换环境（用于测试）
    func setUseMockData(_ useMock: Bool) {
        UserDefaults.standard.set(useMock, forKey: "use_mock_data")
    }
    
    /// 切换北京只读（用于测试或地区切换）
    func setUseBeijingRead(_ use: Bool) {
        UserDefaults.standard.set(use, forKey: "use_beijing_read")
    }
}

