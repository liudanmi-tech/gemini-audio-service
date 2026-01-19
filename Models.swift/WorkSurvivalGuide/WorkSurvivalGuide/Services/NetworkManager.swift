//
//  NetworkManager.swift
//  WorkSurvivalGuide
//
//  网络请求管理器（支持 Mock 和真实 API）
//

import Foundation
import Alamofire

// FastAPI 错误响应格式
struct FastAPIErrorResponse: Codable {
    let detail: String
}

class NetworkManager {
    static let shared = NetworkManager()
    
    private let config = AppConfig.shared
    private let mockService = MockNetworkService.shared
    
    // ⚠️ 重要：修改为你的后端 API 地址
    // 开发阶段：使用 localhost（本地测试）
    // 生产阶段：使用服务器地址（注意端口 8001）
    private let baseURL = "http://47.79.254.213:8001/api/v1"
    
    // 获取 baseURL（供外部使用，用于图片 URL 转换）
    func getBaseURL() -> String {
        return baseURL
    }
    
    private init() {}
    
    // 获取认证 Token（从Keychain读取）
    private func getAuthToken() -> String {
        return KeychainManager.shared.getToken() ?? ""
    }
    
    // 获取任务列表（支持 Mock 和真实 API）
    func getTaskList(
        date: Date? = nil,
        status: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> TaskListResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据获取任务列表")
            return try await mockService.getTaskList(
                date: date,
                status: status,
                page: page,
                pageSize: pageSize
            )
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 获取任务列表")
        var parameters: [String: Any] = [
            "page": page,
            "page_size": pageSize
        ]
        
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            parameters["date"] = formatter.string(from: date)
        }
        
        if let status = status {
            parameters["status"] = status
        }
        
        let dataTask = AF.request(
            "\(baseURL)/tasks/sessions",
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 120 } // 设置超时时间为120秒
        )
        
        // 先获取响应用于检查状态码
        let dataResponse = await dataTask.serializingData().response
        let httpResponse = dataResponse.response
        
        // 检查 HTTP 状态码
        if let statusCode = httpResponse?.statusCode, statusCode == 401 {
            print("🔐 [NetworkManager] 🔴 检测到 401 状态码，立即清除登录状态")
            DispatchQueue.main.async {
                AuthManager.shared.logout()
            }
            
            // 尝试解析 FastAPI 错误格式
            if let responseData = dataResponse.data,
               let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                throw NSError(
                    domain: "NetworkError",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                )
            } else {
                throw NSError(
                    domain: "NetworkError",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "认证失败，请重新登录"]
                )
            }
        }
        
        // 先获取原始响应数据用于调试
        let responseData = try await dataTask.serializingData().value
        print("📥 [NetworkManager] 收到原始响应数据:")
        print("   - 数据长度: \(responseData.count) 字节")
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("   - 响应内容: \(responseString)")
        }
        
        // 检查响应是否为空
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 响应数据为空")
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "服务端返回空响应"]
            )
        }
        
        // 尝试解析 JSON（如果失败，可能是 FastAPI 错误格式）
        do {
            let response = try await dataTask.serializingDecodable(APIResponse<TaskListResponse>.self).value
        
            print("📥 [NetworkManager] 解析后的响应:")
            print("   - code: \(response.code)")
            print("   - message: \(response.message)")
            
            guard response.code == 200, let data = response.data else {
                print("❌ [NetworkManager] 响应错误:")
                print("   - code: \(response.code)")
                print("   - message: \(response.message)")
                throw NSError(
                    domain: "NetworkError",
                    code: response.code,
                    userInfo: [NSLocalizedDescriptionKey: response.message]
                )
            }
            
            print("✅ [NetworkManager] 任务列表获取成功，任务数量: \(data.sessions.count)")
            return data
        } catch let error as DecodingError {
            // 解码失败，可能是 FastAPI 错误格式
            print("⚠️ [NetworkManager] JSON 解码失败，尝试解析 FastAPI 错误格式")
            if let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                let statusCode = httpResponse?.statusCode ?? 400
                print("🔐 [NetworkManager] ✅ 成功解析 FastAPI 错误: \(errorResponse.detail), 状态码: \(statusCode)")
                
                if statusCode == 401 {
                    print("🔐 [NetworkManager] 🔴 收到 401 错误，立即清除登录状态")
                    DispatchQueue.main.async {
                        AuthManager.shared.logout()
                    }
                }
                
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                )
            }
            throw error
        }
    }
    
    // 上传音频文件（支持 Mock 和真实 API）
    func uploadAudio(
        fileURL: URL,
        title: String? = nil
    ) async throws -> UploadResponse {
        print("🌐 [NetworkManager] ========== 上传音频 ==========")
        print("🌐 [NetworkManager] 文件路径: \(fileURL.path)")
        print("🌐 [NetworkManager] 文件是否存在: \(FileManager.default.fileExists(atPath: fileURL.path))")
        
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [NetworkManager] 使用 Mock 数据上传音频")
            let result = try await mockService.uploadAudio(
                fileURL: fileURL,
                sessionId: nil
            )
            print("✅ [NetworkManager] Mock 上传成功: \(result.sessionId)")
            return result
        }
        
        // 使用真实 API
        print("🌐 [NetworkManager] 使用真实 API 上传音频")
        print("🌐 [NetworkManager] API 地址: \(baseURL)/audio/upload")
        
        let uploadTask = AF.upload(
            multipartFormData: { multipartFormData in
                // 添加文件
                print("📤 [NetworkManager] 添加文件到 multipart form data")
                print("   - 文件名: \(fileURL.lastPathComponent)")
                print("   - MIME 类型: audio/m4a")
                multipartFormData.append(
                    fileURL,
                    withName: "file",
                    fileName: fileURL.lastPathComponent,
                    mimeType: "audio/m4a"
                )
                
                // 添加可选的 title
                if let title = title {
                    print("📤 [NetworkManager] 添加 title: \(title)")
                    multipartFormData.append(
                        title.data(using: .utf8)!,
                        withName: "title"
                    )
                }
            },
            to: "\(baseURL)/audio/upload",
            method: .post,
            headers: [
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 180 } // 上传文件需要更长时间，设置180秒
        )
        
        // 监听上传进度
        uploadTask.uploadProgress { progress in
            print("📤 [NetworkManager] 上传进度: \(Int(progress.fractionCompleted * 100))%")
        }
        
        // 先获取原始响应数据用于调试
        let dataResponse = await uploadTask.serializingData().response
        let httpResponse = dataResponse.response
        
        // 检查 HTTP 状态码
        if let statusCode = httpResponse?.statusCode {
            print("📥 [NetworkManager] HTTP 状态码: \(statusCode)")
            
            // 如果是 401，立即清除登录状态
            if statusCode == 401 {
                print("🔐 [NetworkManager] 🔴 检测到 401 状态码，立即清除登录状态")
                DispatchQueue.main.async {
                    AuthManager.shared.logout()
                }
                
                // 尝试解析 FastAPI 错误格式
                if let responseData = dataResponse.data,
                   let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                    throw NSError(
                        domain: "NetworkError",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                    )
                } else {
                    throw NSError(
                        domain: "NetworkError",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "认证失败，请重新登录"]
                    )
                }
            }
        }
        
        let responseData = try await uploadTask.serializingData().value
        print("📥 [NetworkManager] 收到原始响应数据:")
        print("   - 数据长度: \(responseData.count) 字节")
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("   - 响应内容: \(responseString)")
        }
        
        // 检查响应是否为空
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 响应数据为空")
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "服务端返回空响应"]
            )
        }
        
        // 尝试解析 JSON（如果失败，可能是 FastAPI 错误格式）
        do {
            let response = try await uploadTask.serializingDecodable(APIResponse<UploadResponse>.self).value
        
            print("📥 [NetworkManager] 解析后的响应:")
            print("   - code: \(response.code)")
            print("   - message: \(response.message)")
            
            guard response.code == 200, let data = response.data else {
                print("❌ [NetworkManager] 上传失败:")
                print("   - code: \(response.code)")
                print("   - message: \(response.message)")
                throw NSError(
                    domain: "NetworkError",
                    code: response.code,
                    userInfo: [NSLocalizedDescriptionKey: response.message]
                )
            }
            
            print("✅ [NetworkManager] 上传成功:")
            print("   - sessionId: \(data.sessionId)")
            print("   - title: \(data.title)")
            print("   - status: \(data.status)")
            
            return data
        } catch let error as DecodingError {
            // 解码失败，可能是 FastAPI 错误格式
            print("⚠️ [NetworkManager] JSON 解码失败，尝试解析 FastAPI 错误格式")
            if let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                let statusCode = httpResponse?.statusCode ?? 400
                print("🔐 [NetworkManager] ✅ 成功解析 FastAPI 错误: \(errorResponse.detail), 状态码: \(statusCode)")
                
                if statusCode == 401 {
                    print("🔐 [NetworkManager] 🔴 收到 401 错误，立即清除登录状态")
                    DispatchQueue.main.async {
                        AuthManager.shared.logout()
                    }
                }
                
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                )
            }
            throw error
        }
    }
    
    // 获取任务详情
    func getTaskDetail(sessionId: String) async throws -> TaskDetailResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            // Mock 模式下返回空详情
            throw NSError(domain: "MockError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock 模式下不支持详情查询"])
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 获取任务详情")
        let response = try await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 120 } // 设置超时时间为120秒
        )
        .serializingDecodable(APIResponse<TaskDetailResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "NetworkError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        return data
    }
    
    // 获取任务状态
    func getTaskStatus(sessionId: String) async throws -> TaskStatusResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            // Mock 模式下返回默认状态
            return TaskStatusResponse(
                sessionId: sessionId,
                status: "archived",
                progress: 1.0,
                estimatedTimeRemaining: 0,
                updatedAt: Date()
            )
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 获取任务状态")
        let response = try await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)/status",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 120 } // 设置超时时间为120秒
        )
        .serializingDecodable(APIResponse<TaskStatusResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "NetworkError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        return data
    }
    
    // 获取策略分析（包含图片）
    func getStrategyAnalysis(sessionId: String) async throws -> StrategyAnalysisResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据获取策略分析")
            // Mock 模式下返回空数据
            return StrategyAnalysisResponse(
                visual: [],
                strategies: []
            )
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 获取策略分析")
        let response = try await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)/strategies",
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 180 } // 策略分析可能需要更长时间，设置180秒
        )
        .serializingDecodable(APIResponse<StrategyAnalysisResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "NetworkError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        print("✅ [NetworkManager] 策略分析获取成功")
        print("  关键时刻数量: \(data.visual.count)")
        print("  策略数量: \(data.strategies.count)")
        
        return data
    }
}

