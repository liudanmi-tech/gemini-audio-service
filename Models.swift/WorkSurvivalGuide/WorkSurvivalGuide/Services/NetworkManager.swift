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
    
    /// 读接口 baseURL（方案二：北京只读时走北京，否则走新加坡）
    private var baseURLForRead: String { config.useBeijingRead ? config.readBaseURL : config.writeBaseURL }
    
    /// 写接口 baseURL（始终走新加坡）
    private var baseURLForWrite: String { config.writeBaseURL }
    
    /// 获取 baseURL（供外部使用，用于图片 URL 转换。启用北京读时返回北京地址）
    func getBaseURL() -> String {
        return baseURLForRead
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
        let token = getAuthToken()
        guard !token.isEmpty else {
            print("⚠️ [NetworkManager] Token 为空，跳过请求并清除登录状态")
            Task { @MainActor in AuthManager.shared.logout() }
            throw NSError(domain: "NetworkError", code: 401, userInfo: [NSLocalizedDescriptionKey: "请先登录"])
        }
        
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
        
        let requestURL = "\(baseURLForRead)/tasks/sessions"
        print("📡 [NetworkManager] 请求URL: \(requestURL)")
        print("📡 [NetworkManager] 请求参数: \(parameters)")
        print("📡 [NetworkManager] 请求开始时间: \(requestStartTime)")
        
        let dataTask = AF.request(
            requestURL,
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
            ],
            requestModifier: { request in
                request.timeoutInterval = 120 // 任务列表跨网+服务器负载高时可能较慢，120秒超时
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
                Task { @MainActor in
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
        
        // 检查响应是否为空（常见于请求超时或连接中断）
        guard !responseData.isEmpty else {
            print("❌ [NetworkManager] 响应数据为空")
            let msg: String
            if let err = dataResponse.error {
                let d = err.localizedDescription
                if d.contains("timed out") || d.contains("超时") { msg = "请求超时，请检查网络后重试" }
                else if d.contains("offline") || d.contains("network") { msg = "网络不可达，请检查连接" }
                else { msg = "服务端返回空响应 (\(d))" }
            } else {
                msg = "服务端返回空响应，可能是请求超时"
            }
            throw NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
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
                    Task { @MainActor in
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
    /// - Parameters:
    ///   - onProgress: 可选回调，progress 0~1 为上传进度；达到 1.0 后进入等待响应阶段（服务器处理中）
    func uploadAudio(
        fileURL: URL,
        title: String? = nil,
        onProgress: ((Double) -> Void)? = nil
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
        print("🌐 [NetworkManager] API 地址: \(baseURLForWrite)/audio/upload")
        
        // 大文件（>20MB）分段提示：服务端会自动切分后分析
        let fileSizeLimitMB: Int64 = 20
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int64 {
            let sizeMB = Double(size) / (1024 * 1024)
            print("📁 [NetworkManager] 文件大小: \(String(format: "%.1f", sizeMB)) MB")
            if size > fileSizeLimitMB * 1024 * 1024 {
                print("📎 [NetworkManager] 大文件（>\(fileSizeLimitMB)MB），服务端将自动分段上传并分析")
            }
        }
        
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
            to: "\(baseURLForWrite)/audio/upload",
            method: .post,
            headers: [
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 600 } // 大文件(20MB+)上传需更长时间，设置600秒
        )
        
        // 监听上传进度（0~1；达 1.0 后仍需等待服务器处理并返回响应）
        var didLog100 = false
        uploadTask.uploadProgress { progress in
            let pct = progress.fractionCompleted
            print("📤 [NetworkManager] 上传进度: \(Int(pct * 100))%")
            if pct >= 1.0, !didLog100 {
                didLog100 = true
                print("📤 [NetworkManager] 上传数据已发送完毕，等待服务器响应（大文件可能需 10-60 秒）...")
            }
            onProgress?(pct)
        }
        
        print("⏳ [NetworkManager] 开始等待 HTTP 响应（await serializingData）...")
        let dataResponse = await uploadTask.serializingData().response
        let httpResponse = dataResponse.response
        if let err = dataResponse.error {
            print("❌ [NetworkManager] 请求失败: \(err.localizedDescription)")
            print("   domain=\((err as NSError).domain) code=\((err as NSError).code)")
            if (err as NSError).code == -1001 {
                print("   原因: 连接超时（服务器处理时间过长或网络问题）")
            }
        }
        print("📥 [NetworkManager] 已收到响应: statusCode=\(httpResponse?.statusCode ?? 0)")
        
        // 检查 HTTP 状态码
        if let statusCode = httpResponse?.statusCode {
            print("📥 [NetworkManager] HTTP 状态码: \(statusCode)")
            
            // 502/503/504 网关错误（常因大文件上传超时）
            if statusCode == 502 || statusCode == 503 || statusCode == 504 {
                let msg = statusCode == 502
                    ? "服务器暂时不可用，大文件上传可能超时。请尝试：1) 使用较小文件 2) 检查网络 3) 稍后重试"
                    : "服务暂不可用 (HTTP \(statusCode))，请稍后重试"
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: msg]
                )
            }
            
            // 如果是 401，立即清除登录状态
            if statusCode == 401 {
                print("🔐 [NetworkManager] 🔴 检测到 401 状态码，立即清除登录状态")
                Task { @MainActor in
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
            // 解码失败，可能是 FastAPI 错误格式，或服务端返回了 HTML（如 502 页）
            print("⚠️ [NetworkManager] JSON 解码失败，尝试解析 FastAPI 错误格式")
            if let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                let statusCode = httpResponse?.statusCode ?? 400
                print("🔐 [NetworkManager] ✅ 成功解析 FastAPI 错误: \(errorResponse.detail), 状态码: \(statusCode)")
                
                if statusCode == 401 {
                    print("🔐 [NetworkManager] 🔴 收到 401 错误，立即清除登录状态")
                    Task { @MainActor in
                        AuthManager.shared.logout()
                    }
                }
                
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                )
            }
            // 若响应以 < 开头，说明是 HTML（502 等），优先提示服务器问题
            if let str = String(data: responseData, encoding: .utf8), str.trimmingCharacters(in: .whitespaces).hasPrefix("<") {
                let statusCode = httpResponse?.statusCode ?? 502
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "服务器返回异常，大文件上传可能超时，请稍后重试或使用较小文件"]
                )
            }
            throw error
        }
    }
    
    // 获取任务详情
    func getTaskDetail(sessionId: String, authToken: String? = nil) async throws -> TaskDetailResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            // Mock 模式下返回空详情
            throw NSError(domain: "MockError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Mock 模式下不支持详情查询"])
        }
        
        let token = authToken?.isEmpty == false ? authToken! : getAuthToken()
        guard !token.isEmpty else {
            throw NSError(domain: "NetworkError", code: 401, userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"])
        }
        
        // 使用真实 API：先取原始响应，非 200 时按错误体解码，避免 "data is missing"
        print("🌐 [Real] 使用真实 API 获取任务详情")
        let dataResponse = await AF.request(
            "\(baseURLForRead)/tasks/sessions/\(sessionId)",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
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
    
    // 获取任务状态（authToken 可选：轮询时传入缓存的 token，避免被其他请求的 401 登出导致中断）
    func getTaskStatus(sessionId: String, authToken: String? = nil) async throws -> TaskStatusResponse {
        // 如果使用 Mock 数据
        if config.useMockData {
            // Mock 模式下返回默认状态
            return TaskStatusResponse(
                sessionId: sessionId,
                status: "archived",
                progress: 1.0,
                estimatedTimeRemaining: 0,
                updatedAt: Date(),
                failureReason: nil,
                analysisStage: nil
            )
        }
        
        let token = authToken?.isEmpty == false ? authToken! : getAuthToken()
        guard !token.isEmpty else {
            throw NSError(domain: "NetworkError", code: 401, userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"])
        }
        
        // 使用真实 API：分析期间 OSS 下载等同步操作会阻塞，120s 超时；超时后轮询会继续重试
        print("🌐 [Real] 使用真实 API 获取任务状态")
        let dataResponse = await AF.request(
            "\(baseURLForRead)/tasks/sessions/\(sessionId)/status",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
            ],
            requestModifier: { $0.timeoutInterval = 120 }
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        if statusCode != 200 {
            let message: String
            if statusCode == 0, let err = dataResponse.error {
                // HTTP 0：连接层失败，给出更明确的提示
                let errDesc = err.localizedDescription
                if errDesc.contains("timed out") || errDesc.contains("超时") {
                    message = "连接超时，请检查网络后重试"
                } else if errDesc.contains("offline") || errDesc.contains("internet") || errDesc.contains("network") {
                    message = "网络不可达，请检查网络连接"
                } else if errDesc.contains("host") || errDesc.contains("connect") {
                    message = "无法连接服务器，请确认网络或稍后重试"
                } else {
                    message = "连接失败: \(errDesc)"
                }
            } else {
                message = (try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData))?.detail
                    ?? (responseData.isEmpty ? nil : String(data: responseData, encoding: .utf8))
                    ?? "请求失败 (HTTP \(statusCode))"
            }
            throw NSError(domain: "NetworkError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let decoded = try JSONDecoder().decode(APIResponse<TaskStatusResponse>.self, from: responseData)
        guard decoded.code == 200, let data = decoded.data else {
            throw NSError(domain: "NetworkError", code: decoded.code, userInfo: [NSLocalizedDescriptionKey: decoded.message])
        }
        return data
    }
    
    /// 同步用户图片风格偏好到服务端（供新录音自动生成时使用）
    func updateUserPreferences(imageStyle: String) async {
        guard !config.useMockData else {
            print("🎨 [NetworkManager] 跳过同步偏好: Mock 模式")
            return
        }
        guard hasValidToken() else {
            print("🎨 [NetworkManager] 跳过同步偏好: 无有效 Token")
            return
        }
        let url = "\(baseURLForWrite)/users/me/preferences"
        print("🎨 [NetworkManager] 同步偏好到服务端: image_style=\(imageStyle) url=\(url)")
        let body: [String: Any] = ["image_style": imageStyle]
        do {
            let dataResponse = await AF.request(
                url,
                method: .put,
                parameters: body,
                encoding: JSONEncoding.default,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(getAuthToken())"
                ]
            )
            .serializingData()
            .response
            let code = dataResponse.response?.statusCode ?? 0
            print("🎨 [NetworkManager] 偏好同步结果: HTTP \(code)")
            if code != 200, let data = dataResponse.data, let str = String(data: data, encoding: .utf8) {
                print("🎨 [NetworkManager] 偏好同步失败: \(str.prefix(200))")
            }
        } catch {
            print("🎨 [NetworkManager] 偏好同步异常: \(error.localizedDescription)")
        }
    }
    
    // 获取策略分析（包含图片）
    /// - Parameter forceRegenerate: 为 true 时强制重新生成，可修复旧数据无 skill_cards / 图片失败等问题
    func getStrategyAnalysis(sessionId: String, forceRegenerate: Bool = false) async throws -> StrategyAnalysisResponse {
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
        print("🌐 [Real] 使用真实 API 获取策略分析 forceRegenerate=\(forceRegenerate)")
        var url: String
        if forceRegenerate {
            let styleKey = UserDefaults.standard.string(forKey: "image_style") ?? "ghibli"
            let encoded = styleKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? styleKey
            url = "\(baseURLForWrite)/tasks/sessions/\(sessionId)/strategies?force_regenerate=true&image_style=\(encoded)"
            print("🎨 [NetworkManager] 强制重新生成，使用风格: \(styleKey) URL: \(url)")
        } else {
            url = "\(baseURLForRead)/tasks/sessions/\(sessionId)/strategies"
        }
        let dataResponse = await AF.request(
            url,
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 600 }  // 策略生成含场景识别+多技能+多图，需与 Nginx 600s 匹配
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        var responseData = dataResponse.data ?? Data()

        if statusCode != 200 {
            let message: String
            if let errResp = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                message = errResp.detail
            } else if !responseData.isEmpty, let str = String(data: responseData, encoding: .utf8), !str.isEmpty {
                message = str
            } else if statusCode == 0 {
                message = "连接中断或超时，策略可能仍在生成中，请稍后重试"
            } else {
                message = "请求失败 (HTTP \(statusCode))"
            }
            throw NSError(domain: "NetworkError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }

        // 方案二：北京返回 need_generate 时，切换新加坡生成
        if config.useBeijingRead, !forceRegenerate,
           let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
           let data = json["data"] as? [String: Any],
           (data["need_generate"] as? Bool) == true,
           let writeBase = (data["write_base_url"] as? String)?.trimmingCharacters(in: .whitespaces),
           !writeBase.isEmpty {
            print("📡 [NetworkManager] 北京返回 need_generate，切换新加坡生成策略: \(writeBase)")
            let base = writeBase.hasSuffix("/") ? String(writeBase.dropLast()) : writeBase
            let writeURL = "\(base)/api/v1/tasks/sessions/\(sessionId)/strategies"
            let retryResponse = await AF.request(
                writeURL,
                method: .post,
                headers: [
                    "Content-Type": "application/json",
                    "Authorization": "Bearer \(getAuthToken())"
                ],
                requestModifier: { $0.timeoutInterval = 600 }
            )
            .serializingData()
            .response
            if retryResponse.response?.statusCode == 200, let retryData = retryResponse.data, !retryData.isEmpty {
                responseData = retryData
            } else {
                let msg = (try? JSONDecoder().decode(FastAPIErrorResponse.self, from: retryResponse.data ?? Data()))?.detail
                    ?? "策略生成请求失败，请稍后重试"
                throw NSError(domain: "NetworkError", code: retryResponse.response?.statusCode ?? 500,
                              userInfo: [NSLocalizedDescriptionKey: msg])
            }
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
        print("  技能卡片数量: \(data.skillCards?.count ?? 0)")

        return data
    }
    
    // 获取心情趋势（跨对话）
    func getEmotionTrend(limit: Int = 30) async throws -> EmotionTrendResponse {
        if config.useMockData {
            return EmotionTrendResponse(points: [])
        }
        let dataResponse = await AF.request(
            "\(baseURLForRead)/tasks/emotion-trend",
            parameters: ["limit": limit],
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 30 }
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        if statusCode != 200 {
            let message = (try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData))?.detail
                ?? "请求失败 (HTTP \(statusCode))"
            throw NSError(domain: "NetworkError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let decoded = try JSONDecoder().decode(APIResponse<EmotionTrendResponse>.self, from: responseData)
        guard decoded.code == 200, let data = decoded.data else {
            throw NSError(domain: "NetworkError", code: decoded.code, userInfo: [NSLocalizedDescriptionKey: decoded.message])
        }
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
            "\(baseURLForRead)/skills",
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
            "\(baseURLForRead)/profiles",
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
            "\(baseURLForWrite)/profiles",
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
        print("   URL: \(baseURLForWrite)/profiles/\(profile.id)")
        print("   参数: \(parameters)")
        
        let dataTask = AF.request(
            "\(baseURLForWrite)/profiles/\(profile.id)",
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
            "\(baseURLForWrite)/profiles/\(profileId)",
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
    
    // 上传档案照片（profileId 可选，传入则照片与该档案绑定）
    func uploadProfilePhoto(imageData: Data, profileId: String? = nil) async throws -> String {
        guard hasValidToken() else {
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "请先登录"]
            )
        }
        
        var urlString = "\(baseURLForWrite)/profiles/upload-photo"
        if let pid = profileId, !pid.isEmpty {
            urlString += "?profile_id=\(pid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? pid)"
        }
        print("🌐 [NetworkManager] 上传档案照片 profileId=\(profileId ?? "nil")")
        print("  图片大小: \(imageData.count) 字节")
        
        let uploadTask = AF.upload(
            multipartFormData: { multipartFormData in
                multipartFormData.append(
                    imageData,
                    withName: "file",
                    fileName: "profile_photo.jpg",
                    mimeType: "image/jpeg"
                )
            },
            to: urlString,
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
            "\(baseURLForRead)/tasks/sessions/\(sessionId)/audio-segments",
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
        
        let dataResponse = await AF.request(
            "\(baseURLForWrite)/tasks/sessions/\(sessionId)/extract-segment",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 120 } // 提取+上传需更长时间
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        
        guard statusCode >= 200 && statusCode < 300 else {
            // 尝试解析 FastAPI 错误格式 { "detail": "..." }
            if let err = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: responseData) {
                throw NSError(domain: "NetworkError", code: statusCode,
                              userInfo: [NSLocalizedDescriptionKey: err.detail])
            }
            if statusCode == 502 || statusCode == 503 || statusCode == 504 {
                throw NSError(domain: "NetworkError", code: statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "服务器暂时不可用，请稍后重试或选择其他任务"])
            }
            throw NSError(domain: "NetworkError", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "提取失败 (HTTP \(statusCode))"])
        }
        
        let decoded = try JSONDecoder().decode(AudioSegmentExtractResponse.self, from: responseData)
        print("✅ [NetworkManager] 音频片段提取成功")
        return decoded
    }
}

// 空响应类型（用于DELETE等不需要返回数据的请求）
struct EmptyResponse: Codable {
}

