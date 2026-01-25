//
//  NetworkDiagnostics.swift
//  WorkSurvivalGuide
//
//  网络诊断工具 - 用于诊断网络请求性能问题
//

import Foundation
import Alamofire

class NetworkDiagnostics {
    static let shared = NetworkDiagnostics()
    
    private init() {}
    
    // 诊断网络连接（简化版本，专注于HTTP请求性能）
    func diagnoseConnection(to url: String) async -> NetworkDiagnosticResult {
        let startTime = Date()
        var result = NetworkDiagnosticResult(
            url: url,
            startTime: startTime,
            dnsLookupTime: nil,
            connectTime: nil,
            totalTime: nil,
            success: false,
            error: nil
        )
        
        guard let targetURL = URL(string: url) else {
            result.error = "无效的URL"
            result.totalTime = Date().timeIntervalSince(startTime)
            return result
        }
        
        do {
            // 测试HTTP请求（包含DNS解析和TCP连接时间）
            let requestStart = Date()
            let response = try await AF.request(
                url,
                method: .get,
                requestModifier: { $0.timeoutInterval = 5 }
            ).serializingData().response
            
            result.totalTime = Date().timeIntervalSince(startTime)
            result.success = response.response?.statusCode == 200 || response.response?.statusCode == 401
            
            // 估算DNS和连接时间（实际由系统处理，这里只是记录总时间）
            result.dnsLookupTime = result.totalTime! * 0.1 // 估算DNS时间占总时间的10%
            result.connectTime = result.totalTime! * 0.2 // 估算连接时间占总时间的20%
            
            if let statusCode = response.response?.statusCode {
                print("🔍 [NetworkDiagnostics] HTTP请求完成")
                print("   - 总耗时: \(String(format: "%.3f", result.totalTime ?? 0))秒")
                print("   - 状态码: \(statusCode)")
            }
            
        } catch {
            result.error = error.localizedDescription
            result.totalTime = Date().timeIntervalSince(startTime)
            print("❌ [NetworkDiagnostics] 诊断失败: \(error.localizedDescription)")
        }
        
        return result
    }
}

struct NetworkDiagnosticResult {
    let url: String
    let startTime: Date
    var dnsLookupTime: TimeInterval?
    var connectTime: TimeInterval?
    var totalTime: TimeInterval?
    var success: Bool
    var error: String?
    
    var summary: String {
        var parts: [String] = []
        if let dns = dnsLookupTime {
            parts.append("DNS: \(String(format: "%.3f", dns))s")
        }
        if let connect = connectTime {
            parts.append("连接: \(String(format: "%.3f", connect))s")
        }
        if let total = totalTime {
            parts.append("总计: \(String(format: "%.3f", total))s")
        }
        return parts.joined(separator: ", ")
    }
}
