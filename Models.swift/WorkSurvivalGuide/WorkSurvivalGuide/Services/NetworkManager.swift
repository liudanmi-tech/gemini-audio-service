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
    // 生产阶段：使用 80 端口经 Nginx 转发（安全组已放行 80）
    private let baseURL = "http://47.79.254.213/api/v1"
    
    // 获取 baseURL（供外部使用，用于图片 URL 转换）
    func getBaseURL() -> String {
        return baseURL
    }
    
    private init() {}
    
    // 获取认证 Token（从Keychain读取）
    private func getAuthToken() -> String {
        let token = KeychainManager.shared.getToken() ?? ""
        if token.isEmpty {
            print("⚠️ [NetworkManager] Token为空，请先登录")
        }
        return token
    }
    
    // 检查是否有有效的认证token
    func hasValidToken() -> Bool {
        return !(KeychainManager.shared.getToken() ?? "").isEmpty
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
        let requestStartTime = Date()
        
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
        
        let requestURL = "\(baseURL)/tasks/sessions"
        print("📡 [NetworkManager] 请求URL: \(requestURL)")
        print("📡 [NetworkManager] 请求参数: \(parameters)")
        print("📡 [NetworkManager] 请求开始时间: \(requestStartTime)")
        
        let dataTask = AF.request(
            requestURL,
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { request in
                request.timeoutInterval = 10 // 优化超时时间为10秒
                // 添加请求开始时间戳（用于诊断）
                request.setValue("\(requestStartTime.timeIntervalSince1970)", forHTTPHeaderField: "X-Request-Start")
            }
        )
        
        // 先获取响应用于检查状态码
        let responseStartTime = Date()
        let dataResponse = await dataTask.serializingData().response
        let responseTime = Date().timeIntervalSince(responseStartTime)
        let totalRequestTime = Date().timeIntervalSince(requestStartTime)
        
        print("⏱️ [NetworkManager] 请求耗时统计:")
        print("   - 响应时间: \(String(format: "%.3f", responseTime))秒")
        print("   - 总耗时: \(String(format: "%.3f", totalRequestTime))秒")
        
        let httpResponse = dataResponse.response
        let responseData = dataResponse.data ?? Data()
        
        // 检查 HTTP 状态码
        if let statusCode = httpResponse?.statusCode {
            if statusCode == 401 {
                print("🔐 [NetworkManager] 🔴 检测到 401 状态码，立即清除登录状态")
                DispatchQueue.main.async {
                    AuthManager.shared.logout()
                }
                
                // 尝试解析 FastAPI 错误格式
                if !responseData.isEmpty,
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
            } else if statusCode != 200 {
                // 其他非200状态码
                print("❌ [NetworkManager] HTTP 状态码: \(statusCode)")
                if !responseData.isEmpty, let responseString = String(data: responseData, encoding: .utf8) {
                    print("   响应内容: \(responseString)")
                }
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode) 错误"]
                )
            }
        }
        
        print("📥 [NetworkManager] 收到原始响应数据:")
        print("   - 数据长度: \(responseData.count) 字节")
        
        // 只在调试模式下打印完整响应内容（避免日志过多）
        #if DEBUG
        if responseData.count < 1000, let responseString = String(data: responseData, encoding: .utf8) {
            print("   - 响应内容: \(responseString)")
        }
        #endif
        
        // 检查响应是否为空
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 响应数据为空")
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "服务端返回空响应"]
            )
        }
        
        // 尝试解析 JSON（使用已获取的响应数据）
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let response = try decoder.decode(APIResponse<TaskListResponse>.self, from: responseData)
        
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
        
        // 使用真实 API：先取原始响应，非 200 时按错误体解码，避免 "data is missing"
        print("🌐 [Real] 使用真实 API 获取任务详情")
        let dataResponse = await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 60 }
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        if statusCode != 200 {
            let message = (try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData))?.detail
                ?? (responseData.isEmpty ? nil : String(data: responseData, encoding: .utf8))
                ?? "请求失败 (HTTP \(statusCode))"
            throw NSError(domain: "NetworkError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let decoded = try JSONDecoder().decode(APIResponse<TaskDetailResponse>.self, from: responseData)
        guard decoded.code == 200, let data = decoded.data else {
            throw NSError(domain: "NetworkError", code: decoded.code, userInfo: [NSLocalizedDescriptionKey: decoded.message])
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
                updatedAt: Date(),
                failureReason: nil
            )
        }
        
        // 使用真实 API：先取原始响应，非 200 时按错误体解码，避免 "data is missing"
        print("🌐 [Real] 使用真实 API 获取任务状态")
        let dataResponse = await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)/status",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 120 }
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        if statusCode != 200 {
            let message = (try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData))?.detail
                ?? (responseData.isEmpty ? nil : String(data: responseData, encoding: .utf8))
                ?? "请求失败 (HTTP \(statusCode))"
            throw NSError(domain: "NetworkError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let decoded = try JSONDecoder().decode(APIResponse<TaskStatusResponse>.self, from: responseData)
        guard decoded.code == 200, let data = decoded.data else {
            throw NSError(domain: "NetworkError", code: decoded.code, userInfo: [NSLocalizedDescriptionKey: decoded.message])
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
        
        // 使用真实 API：先取原始响应，按状态码分支解码，避免 4xx/5xx 时用成功结构解码导致 "data is missing"
        print("🌐 [Real] 使用真实 API 获取策略分析")
        let dataResponse = await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)/strategies",
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 180 }
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        
        if statusCode != 200 {
            let message: String
            if let errResp = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                message = errResp.detail
            } else if !responseData.isEmpty, let str = String(data: responseData, encoding: .utf8), !str.isEmpty {
                message = str
            } else {
                message = "请求失败 (HTTP \(statusCode))"
            }
            throw NSError(domain: "NetworkError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        
        let decoded = try JSONDecoder().decode(APIResponse<StrategyAnalysisResponse>.self, from: responseData)
        guard decoded.code == 200, let data = decoded.data else {
            throw NSError(
                domain: "NetworkError",
                code: decoded.code,
                userInfo: [NSLocalizedDescriptionKey: decoded.message]
            )
        }
        
        print("✅ [NetworkManager] 策略分析获取成功")
        print("  关键时刻数量: \(data.visual.count)")
        print("  策略数量: \(data.strategies.count)")
        
        return data
    }
    
    // 获取技能列表
    func getSkillsList(
        category: String? = nil,
        enabled: Bool = true
    ) async throws -> SkillListResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据获取技能列表")
            // Mock 模式下返回空列表
            return SkillListResponse(skills: [])
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 获取技能列表")
        var parameters: [String: Any] = [
            "enabled": enabled
        ]
        
        if let category = category {
            parameters["category"] = category
        }
        
        // 检查token是否为空
        guard hasValidToken() else {
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "请先登录"]
            )
        }
        
        let dataTask = AF.request(
            "\(baseURL)/skills",
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 10 } // 优化超时时间为10秒
        )
        
        // 先检查HTTP状态码
        let dataResponse = await dataTask.serializingData().response
        let responseData = dataResponse.data ?? Data()
        
        if let statusCode = dataResponse.response?.statusCode {
            if statusCode == 401 {
                print("🔐 [NetworkManager] 技能列表请求返回 401，认证失败")
                throw NSError(
                    domain: "NetworkError",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "认证失败，请重新登录"]
                )
            } else if statusCode != 200 {
                print("❌ [NetworkManager] 技能列表 HTTP 状态码: \(statusCode)")
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode) 错误"]
                )
            }
        }
        
        // 检查响应数据是否为空
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 技能列表响应数据为空")
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "服务端返回空响应"]
            )
        }
        
        // 使用已获取的响应数据解析
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(APIResponse<SkillListResponse>.self, from: responseData)
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "NetworkError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        print("✅ [NetworkManager] 技能列表获取成功")
        print("  技能数量: \(data.skills.count)")
        
        return data
    }
    
    // MARK: - 档案管理API
    
    // 获取档案列表
    func getProfilesList() async throws -> ProfileListResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据获取档案列表")
            return ProfileListResponse(profiles: [])
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 获取档案列表")
        
        // 检查token是否为空
        guard hasValidToken() else {
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "请先登录"]
            )
        }
        
        let dataTask = AF.request(
            "\(baseURL)/profiles",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 10 }
        )
        
        // 先检查HTTP状态码
        let dataResponse = await dataTask.serializingData().response
        let responseData = dataResponse.data ?? Data()
        
        if let statusCode = dataResponse.response?.statusCode {
            if statusCode == 401 {
                print("🔐 [NetworkManager] 档案列表请求返回 401，认证失败")
                throw NSError(
                    domain: "NetworkError",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "认证失败，请重新登录"]
                )
            } else if statusCode != 200 {
                print("❌ [NetworkManager] 档案列表 HTTP 状态码: \(statusCode)")
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode) 错误"]
                )
            }
        }
        
        // 检查响应数据是否为空
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 档案列表响应数据为空")
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "服务端返回空响应"]
            )
        }
        
        // 打印原始响应用于调试
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("📥 [NetworkManager] 档案列表响应: \(responseString.prefix(500))...") // 只打印前500字符
        }
        
        // 使用已获取的响应数据解析
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profiles = try decoder.decode([Profile].self, from: responseData)
        
        // 打印每个档案的photoUrl
        for profile in profiles {
            print("📷 [NetworkManager] 档案 \(profile.id) photoUrl: \(profile.photoUrl ?? "nil")")
        }
        
        let response = ProfileListResponse(profiles: profiles)
        print("✅ [NetworkManager] 档案列表获取成功，数量: \(response.profiles.count)")
        return response
    }
    
    // 创建档案
    func createProfile(_ profile: Profile) async throws -> Profile {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据创建档案")
            return profile
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 创建档案")
        
        // 构建请求参数（只包含服务器需要的字段）
        let parameters: [String: Any] = [
            "name": profile.name,
            "relationship": profile.relationship,
            "photo_url": profile.photoUrl as Any,
            "notes": profile.notes as Any,
            "audio_session_id": profile.audioSessionId as Any,
            "audio_segment_id": profile.audioSegmentId as Any,
            "audio_start_time": profile.audioStartTime as Any,
            "audio_end_time": profile.audioEndTime as Any,
            "audio_url": profile.audioUrl as Any
        ]
        
        let response = try await AF.request(
            "\(baseURL)/profiles",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 10 }
        )
        .serializingData()
        .response
        
        // 检查状态码
        if let statusCode = response.response?.statusCode {
            print("📊 [NetworkManager] 创建档案 HTTP 状态码: \(statusCode)")
            if statusCode != 201 && statusCode != 200 {
                if let data = response.data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [NetworkManager] 创建档案错误响应: \(errorString)")
                }
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"]
                )
            }
        }
        
        guard let data = response.data else {
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "响应数据为空"]
            )
        }
        
        // 打印原始响应用于调试
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 [NetworkManager] 创建档案响应: \(responseString)")
        }
        
        // 尝试解析响应
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(Profile.self, from: data)
        
        print("✅ [NetworkManager] 档案创建成功，ID: \(profile.id)")
        return profile
    }
    
    // 更新档案
    func updateProfile(_ profile: Profile) async throws -> Profile {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据更新档案")
            return profile
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 更新档案")
        
        // 构建请求参数（只包含服务器需要的字段）
        var parameters: [String: Any] = [:]
        if !profile.name.isEmpty {
            parameters["name"] = profile.name
        }
        if !profile.relationship.isEmpty {
            parameters["relationship"] = profile.relationship
        }
        if let photoUrl = profile.photoUrl {
            parameters["photo_url"] = photoUrl
        }
        if let notes = profile.notes {
            parameters["notes"] = notes
        }
        if let audioSessionId = profile.audioSessionId {
            parameters["audio_session_id"] = audioSessionId
        }
        if let audioSegmentId = profile.audioSegmentId {
            parameters["audio_segment_id"] = audioSegmentId
        }
        if let audioStartTime = profile.audioStartTime {
            parameters["audio_start_time"] = audioStartTime
        }
        if let audioEndTime = profile.audioEndTime {
            parameters["audio_end_time"] = audioEndTime
        }
        if let audioUrl = profile.audioUrl {
            parameters["audio_url"] = audioUrl
        }
        
        // 检查token是否为空
        guard hasValidToken() else {
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "请先登录"]
            )
        }
        
        print("📤 [NetworkManager] 更新档案请求:")
        print("   URL: \(baseURL)/profiles/\(profile.id)")
        print("   参数: \(parameters)")
        
        let dataTask = AF.request(
            "\(baseURL)/profiles/\(profile.id)",
            method: .put,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 30 } // 增加超时时间到30秒
        )
        
        // 先检查HTTP状态码
        let dataResponse = await dataTask.serializingData().response
        let responseData = dataResponse.data ?? Data()
        
        if let statusCode = dataResponse.response?.statusCode {
            if statusCode == 401 {
                print("🔐 [NetworkManager] 更新档案返回 401，认证失败")
                throw NSError(
                    domain: "NetworkError",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "认证失败，请重新登录"]
                )
            } else if statusCode != 200 {
                print("❌ [NetworkManager] 更新档案 HTTP 状态码: \(statusCode)")
                if !responseData.isEmpty, let responseString = String(data: responseData, encoding: .utf8) {
                    print("   响应内容: \(responseString)")
                }
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode) 错误"]
                )
            }
        }
        
        // 检查响应数据是否为空
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 更新档案响应数据为空")
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "服务端返回空响应"]
            )
        }
        
        // 打印原始响应用于调试
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("📥 [NetworkManager] 更新档案响应: \(responseString)")
        }
        
        // 使用已获取的响应数据解析
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let updatedProfile = try decoder.decode(Profile.self, from: responseData)
        
        print("✅ [NetworkManager] 档案更新成功，ID: \(updatedProfile.id)")
        print("📷 [NetworkManager] 更新后的photoUrl: \(updatedProfile.photoUrl ?? "nil")")
        return updatedProfile
    }
    
    // 删除档案
    func deleteProfile(_ profileId: String) async throws {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据删除档案")
            return
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 删除档案")
        let response = try await AF.request(
            "\(baseURL)/profiles/\(profileId)",
            method: .delete,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 10 }
        )
        .validate(statusCode: 200..<300)
        .serializingData()
        .value
        
        print("✅ [NetworkManager] 档案删除成功")
    }
    
    // MARK: - 图片上传API
    
    // 上传档案照片
    func uploadProfilePhoto(imageData: Data) async throws -> String {
        // 检查token是否为空
        guard hasValidToken() else {
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "请先登录"]
            )
        }
        
        print("🌐 [NetworkManager] 上传档案照片")
        print("  图片大小: \(imageData.count) 字节")
        
        let uploadTask = AF.upload(
            multipartFormData: { multipartFormData in
                // 添加图片文件
                multipartFormData.append(
                    imageData,
                    withName: "file",
                    fileName: "profile_photo.jpg",
                    mimeType: "image/jpeg"
                )
            },
            to: "\(baseURL)/profiles/upload-photo",
            method: .post,
            headers: [
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 60 } // 图片上传到OSS需要更长时间，增加到60秒
        )
        
        // 监听上传进度
        uploadTask.uploadProgress { progress in
            print("📤 [NetworkManager] 图片上传进度: \(Int(progress.fractionCompleted * 100))%")
        }
        
        // 先获取响应数据用于检查状态码和解析
        let dataResponse = await uploadTask.serializingData().response
        let responseData = dataResponse.data ?? Data()
        
        if let statusCode = dataResponse.response?.statusCode {
            if statusCode == 401 {
                print("🔐 [NetworkManager] 图片上传返回 401，认证失败")
                throw NSError(
                    domain: "NetworkError",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "认证失败，请重新登录"]
                )
            } else if statusCode != 200 {
                print("❌ [NetworkManager] 图片上传 HTTP 状态码: \(statusCode)")
                if !responseData.isEmpty, let responseString = String(data: responseData, encoding: .utf8) {
                    print("   响应内容: \(responseString)")
                }
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode) 错误"]
                )
            }
        }
        
        // 检查响应数据是否为空
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 图片上传响应数据为空")
            throw NSError(
                domain: "NetworkError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "服务端返回空响应"]
            )
        }
        
        // 打印原始响应用于调试
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("📥 [NetworkManager] 图片上传响应: \(responseString)")
        }
        
        // 解析响应
        struct PhotoUploadResponse: Codable {
            let photo_url: String
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(PhotoUploadResponse.self, from: responseData)
        
        print("✅ [NetworkManager] 图片上传成功")
        print("  图片URL: \(response.photo_url)")
        
        return response.photo_url
    }
    
    // MARK: - 音频片段API
    
    // 获取对话的音频片段列表
    func getAudioSegments(sessionId: String) async throws -> AudioSegmentListResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据获取音频片段列表")
            return AudioSegmentListResponse(segments: [])
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 获取音频片段列表")
        let dataResponse = try await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)/audio-segments",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 10 }
        )
        .serializingData()
        .value
        
        // 打印原始响应用于调试
        if let responseString = String(data: dataResponse, encoding: .utf8) {
            print("📥 [NetworkManager] 音频片段列表响应: \(responseString)")
        }
        
        // 尝试解析响应（服务器直接返回数组）
        let decoder = JSONDecoder()
        let segments = try decoder.decode([AudioSegment].self, from: dataResponse)
        let response = AudioSegmentListResponse(segments: segments)
        
        print("✅ [NetworkManager] 音频片段列表获取成功，数量: \(response.segments.count)")
        return response
    }
    
    // 提取音频片段
    func extractAudioSegment(sessionId: String, startTime: Double, endTime: Double, speaker: String) async throws -> AudioSegmentExtractResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            print("📦 [Mock] 使用 Mock 数据提取音频片段")
            return AudioSegmentExtractResponse(
                segmentId: UUID().uuidString,
                audioUrl: "",
                duration: endTime - startTime
            )
        }
        
        // 使用真实 API
        print("🌐 [Real] 使用真实 API 提取音频片段")
        let parameters: [String: Any] = [
            "start_time": startTime,
            "end_time": endTime,
            "speaker": speaker
        ]
        
        // 后端直接返回 ExtractSegmentResponse，未使用 APIResponse 包装
        let response = try await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)/extract-segment",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 30 } // 音频提取可能需要更长时间
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(AudioSegmentExtractResponse.self)
        .value
        
        print("✅ [NetworkManager] 音频片段提取成功")
        return response
    }
}

// 空响应类型（用于DELETE等不需要返回数据的请求）
struct EmptyResponse: Codable {
}

