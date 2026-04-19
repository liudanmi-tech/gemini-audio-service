//
//  DetailCacheManager.swift
//  WorkSurvivalGuide
//
//  详情缓存管理器 - 用于缓存任务详情和策略分析数据
//

import Foundation

class DetailCacheManager {
    static let shared = DetailCacheManager()
    
    // 缓存任务详情（sessionId -> TaskDetailResponse）
    private var detailCache: [String: TaskDetailResponse] = [:]
    
    // 缓存策略分析（sessionId -> StrategyAnalysisResponse）
    private var strategyCache: [String: StrategyAnalysisResponse] = [:]
    
    // 缓存加载状态（sessionId -> 是否正在加载）
    private var loadingStates: [String: Bool] = [:]
    
    // 缓存时间戳（sessionId -> 缓存时间）
    private var cacheTimestamps: [String: Date] = [:]
    
    // 缓存有效期（30分钟）
    private let cacheValidityDuration: TimeInterval = 1800
    
    private init() {
        // 私有初始化器，确保单例模式
    }
    
    // MARK: - 任务详情缓存
    
    // 获取缓存的详情
    func getCachedDetail(sessionId: String) -> TaskDetailResponse? {
        // 检查缓存是否有效
        if let timestamp = cacheTimestamps[sessionId],
           Date().timeIntervalSince(timestamp) < cacheValidityDuration,
           let detail = detailCache[sessionId] {
            return detail
        }
        
        // 缓存过期或不存在，清除
        detailCache.removeValue(forKey: sessionId)
        cacheTimestamps.removeValue(forKey: sessionId)
        return nil
    }
    
    // 缓存详情
    func cacheDetail(_ detail: TaskDetailResponse, for sessionId: String) {
        detailCache[sessionId] = detail
        cacheTimestamps[sessionId] = Date()
        print("✅ [DetailCacheManager] 已缓存任务详情: \(sessionId)")
    }
    
    // 检查是否正在加载
    func isLoadingDetail(for sessionId: String) -> Bool {
        return loadingStates[sessionId] ?? false
    }
    
    // 设置加载状态
    func setLoadingDetail(_ loading: Bool, for sessionId: String) {
        loadingStates[sessionId] = loading
    }
    
    // MARK: - 策略分析缓存
    
    // 获取缓存的策略分析
    func getCachedStrategy(sessionId: String) -> StrategyAnalysisResponse? {
        // 检查缓存是否有效
        if let timestamp = cacheTimestamps[sessionId],
           Date().timeIntervalSince(timestamp) < cacheValidityDuration,
           let strategy = strategyCache[sessionId] {
            return strategy
        }
        
        // 缓存过期或不存在，清除
        strategyCache.removeValue(forKey: sessionId)
        return nil
    }
    
    // 缓存策略分析
    func cacheStrategy(_ strategy: StrategyAnalysisResponse, for sessionId: String) {
        strategyCache[sessionId] = strategy
        cacheTimestamps[sessionId] = Date()
        print("✅ [DetailCacheManager] 已缓存策略分析: \(sessionId)")
    }
    
    // 检查是否正在加载策略
    func isLoadingStrategy(for sessionId: String) -> Bool {
        return loadingStates["strategy_\(sessionId)"] ?? false
    }
    
    // 设置策略加载状态
    func setLoadingStrategy(_ loading: Bool, for sessionId: String) {
        loadingStates["strategy_\(sessionId)"] = loading
    }
    
    // MARK: - 缓存管理
    
    // 清除指定任务的缓存
    func clearCache(for sessionId: String) {
        detailCache.removeValue(forKey: sessionId)
        strategyCache.removeValue(forKey: sessionId)
        loadingStates.removeValue(forKey: sessionId)
        loadingStates.removeValue(forKey: "strategy_\(sessionId)")
        cacheTimestamps.removeValue(forKey: sessionId)
        print("🗑️ [DetailCacheManager] 已清除缓存: \(sessionId)")
    }
    
    // 清除所有缓存
    func clearAllCache() {
        detailCache.removeAll()
        strategyCache.removeAll()
        loadingStates.removeAll()
        cacheTimestamps.removeAll()
        print("🗑️ [DetailCacheManager] 已清除所有缓存")
    }
    
    // 清除过期缓存
    func clearExpiredCache() {
        let now = Date()
        let expiredKeys = cacheTimestamps.filter { _, timestamp in
            now.timeIntervalSince(timestamp) >= cacheValidityDuration
        }.keys
        
        for key in expiredKeys {
            detailCache.removeValue(forKey: key)
            strategyCache.removeValue(forKey: key)
            loadingStates.removeValue(forKey: key)
            loadingStates.removeValue(forKey: "strategy_\(key)")
            cacheTimestamps.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            print("🗑️ [DetailCacheManager] 已清除 \(expiredKeys.count) 个过期缓存")
        }
    }
}
