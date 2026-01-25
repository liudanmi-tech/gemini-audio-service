import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()
    
    // ⚠️ 重要：修改为你的后端 API 地址
    // 注意：iOS 设备上不能使用 localhost，需要使用实际的服务器 IP 或域名
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
    
    // MARK: - 错误处理辅助方法
    
    /// 处理网络响应，兼容 FastAPI 错误格式
    /// 当收到 401 错误时，自动清除登录状态
    private func handleResponse<T: Codable>(
        _ response: DataResponse<APIResponse<T>, AFError>,
        expectedType: T.Type
    ) throws -> T {
        print("🔍 [NetworkManager] handleResponse 被调用")
        print("🔍 [NetworkManager] 响应状态码: \(response.response?.statusCode ?? -1)")
        print("🔍 [NetworkManager] 响应数据长度: \(response.data?.count ?? 0)")
        
        // 首先检查响应数据和状态码
        if let data = response.data, let statusCode = response.response?.statusCode {
            print("🔍 [NetworkManager] 尝试解析响应数据: \(String(data: data, encoding: .utf8) ?? "无法解析")")
            
            // 优先尝试解析 FastAPI 错误格式
            if let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: data) {
                print("🔐 [NetworkManager] ✅ 检测到 FastAPI 错误格式: \(errorResponse.detail), 状态码: \(statusCode)")
                
                // 如果是 401，清除登录状态
                if statusCode == 401 {
                    print("🔐 [NetworkManager] 🔴 收到 401 错误，立即清除登录状态")
                    DispatchQueue.main.async {
                        print("🔐 [NetworkManager] 执行 logout()")
                        AuthManager.shared.logout()
                    }
                }
                
                throw NSError(
                    domain: "NetworkError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                )
            }
            
            // 如果状态码是 401 但没有 FastAPI 错误格式，也清除登录状态
            if statusCode == 401 {
                print("🔐 [NetworkManager] 🔴 收到 401 错误（无错误详情），立即清除登录状态")
                DispatchQueue.main.async {
                    print("🔐 [NetworkManager] 执行 logout()")
                    AuthManager.shared.logout()
                }
                throw NSError(
                    domain: "NetworkError",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "认证失败，请重新登录"]
                )
            }
        }
        
        // 尝试解析标准响应
        do {
            let apiResponse = try response.result.get()
            guard apiResponse.code == 200, let data = apiResponse.data else {
                throw NSError(
                    domain: "NetworkError",
                    code: apiResponse.code,
                    userInfo: [NSLocalizedDescriptionKey: apiResponse.message]
                )
            }
            return data
        } catch let error as AFError {
            print("⚠️ [NetworkManager] 捕获到 AFError: \(error)")
            
            // 如果是 Alamofire 解码错误，再次尝试解析 FastAPI 错误格式
            if case .responseSerializationFailed(let reason) = error {
                print("⚠️ [NetworkManager] 响应序列化失败: \(reason)")
                if case .decodingFailed(let decodingError) = reason {
                    print("⚠️ [NetworkManager] 解码失败: \(decodingError)")
                    print("⚠️ [NetworkManager] 再次尝试解析 FastAPI 错误格式")
                    
                    if let data = response.data {
                        print("🔍 [NetworkManager] 响应数据: \(String(data: data, encoding: .utf8) ?? "无法解析")")
                        if let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: data) {
                            let statusCode = response.response?.statusCode ?? 400
                            print("🔐 [NetworkManager] ✅ 成功解析 FastAPI 错误: \(errorResponse.detail), 状态码: \(statusCode)")
                            
                            if statusCode == 401 {
                                print("🔐 [NetworkManager] 🔴 收到 401 错误，立即清除登录状态")
                                DispatchQueue.main.async {
                                    print("🔐 [NetworkManager] 执行 logout()")
                                    AuthManager.shared.logout()
                                }
                            }
                            
                            throw NSError(
                                domain: "NetworkError",
                                code: statusCode,
                                userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                            )
                        }
                    }
                }
            }
            throw error
        } catch {
            print("⚠️ [NetworkManager] 捕获到其他错误: \(error)")
            
            // 其他错误，最后尝试解析 FastAPI 错误格式
            if let data = response.data {
                print("🔍 [NetworkManager] 最后尝试解析 FastAPI 错误格式")
                if let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: data) {
                    let statusCode = response.response?.statusCode ?? 400
                    print("🔐 [NetworkManager] ✅ 成功解析 FastAPI 错误: \(errorResponse.detail), 状态码: \(statusCode)")
                    
                    if statusCode == 401 {
                        print("🔐 [NetworkManager] 🔴 收到 401 错误，立即清除登录状态")
                        DispatchQueue.main.async {
                            print("🔐 [NetworkManager] 执行 logout()")
                            AuthManager.shared.logout()
                        }
                    }
                    
                    throw NSError(
                        domain: "NetworkError",
                        code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: errorResponse.detail]
                    )
                }
            }
            throw error
        }
    }
    
    // 获取任务列表
    func getTaskList(
        date: Date? = nil,
        status: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> TaskListResponse {
        // 检查是否有 token
        let token = getAuthToken()
        guard !token.isEmpty else {
            print("⚠️ [NetworkManager] 未登录，无法获取任务列表")
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"]
            )
        }
        
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
        
        let response = await AF.request(
            "\(baseURL)/tasks/sessions",
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
            ],
            requestModifier: { $0.timeoutInterval = 120 } // 设置超时时间为120秒
        )
        .serializingDecodable(APIResponse<TaskListResponse>.self)
        .response
        
        return try handleResponse(response, expectedType: TaskListResponse.self)
    }
    
    // 上传音频文件
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        // 检查是否有 token
        let token = getAuthToken()
        guard !token.isEmpty else {
            print("⚠️ [NetworkManager] 未登录，无法上传音频")
            Task { @MainActor in
                AuthManager.shared.logout()
            }
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"]
            )
        }
        
        print("📤 [NetworkManager] 开始上传音频文件")
        
        let response = await AF.upload(
            multipartFormData: { multipartFormData in
                // 添加文件
                multipartFormData.append(
                    fileURL,
                    withName: "file",
                    fileName: fileURL.lastPathComponent,
                    mimeType: "audio/m4a"
                )
                
                // 添加可选的 session_id
                if let sessionId = sessionId {
                    multipartFormData.append(
                        sessionId.data(using: .utf8)!,
                        withName: "session_id"
                    )
                }
            },
            to: "\(baseURL)/audio/upload",
            method: .post,
            headers: [
                "Authorization": "Bearer \(token)"
            ],
            requestModifier: { $0.timeoutInterval = 180 } // 上传文件可能需要更长时间，设置180秒
        )
        .serializingDecodable(APIResponse<UploadResponse>.self)
        .response
        
        print("📥 [NetworkManager] 收到响应，准备处理")
        print("📥 [NetworkManager] HTTP 状态码: \(response.response?.statusCode ?? -1)")
        if let data = response.data {
            print("📥 [NetworkManager] 响应数据: \(String(data: data, encoding: .utf8) ?? "无法解析")")
        }
        
        // 先检查是否是 401 错误
        if let statusCode = response.response?.statusCode, statusCode == 401 {
            print("🔐 [NetworkManager] 🔴 检测到 401 状态码，立即清除登录状态")
            DispatchQueue.main.async {
                AuthManager.shared.logout()
            }
            
            // 尝试解析 FastAPI 错误格式
            if let data = response.data,
               let errorResponse = try? JSONDecoder().decode(FastAPIErrorResponse.self, from: data) {
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
        
        return try handleResponse(response, expectedType: UploadResponse.self)
    }
    
    // 获取任务详情
    func getTaskDetail(sessionId: String) async throws -> TaskDetailResponse {
        // 检查是否有 token
        let token = getAuthToken()
        guard !token.isEmpty else {
            print("⚠️ [NetworkManager] 未登录，无法获取任务详情")
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"]
            )
        }
        
        let response = await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)",
            method: .get,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
            ],
            requestModifier: { $0.timeoutInterval = 120 } // 设置超时时间为120秒
        )
        .serializingDecodable(APIResponse<TaskDetailResponse>.self)
        .response
        
        return try handleResponse(response, expectedType: TaskDetailResponse.self)
    }
    
    // 获取策略分析（包含图片）
    func getStrategyAnalysis(sessionId: String) async throws -> StrategyAnalysisResponse {
        // 检查是否有 token
        let token = getAuthToken()
        guard !token.isEmpty else {
            print("⚠️ [NetworkManager] 未登录，无法获取策略分析")
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"]
            )
        }
        
        let response = await AF.request(
            "\(baseURL)/tasks/sessions/\(sessionId)/strategies",
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
            ],
            requestModifier: { $0.timeoutInterval = 180 } // 策略分析可能需要更长时间，设置180秒
        )
        .serializingDecodable(APIResponse<StrategyAnalysisResponse>.self)
        .response
        
        // 打印原始响应数据（用于调试）
        if let data = response.data {
            print("📥 [NetworkManager] 策略分析原始响应数据:")
            print("   - 数据长度: \(data.count) 字节")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("   - 响应内容: \(jsonString.prefix(1000))...")  // 只打印前1000字符
            }
        }
        
        let result = try handleResponse(response, expectedType: StrategyAnalysisResponse.self)
        
        // 打印解析后的技能信息
        print("📊 [NetworkManager] 策略分析解析结果:")
        print("   - 关键时刻数量: \(result.visual.count)")
        print("   - 策略数量: \(result.strategies.count)")
        if let skills = result.appliedSkills {
            print("   - 应用技能数量: \(skills.count)")
            for skill in skills {
                print("     * \(skill.skillId) (priority: \(skill.priority), confidence: \(skill.confidence ?? 0))")
            }
        } else {
            print("   - ⚠️ 应用技能: nil")
        }
        print("   - 场景类别: \(result.sceneCategory ?? "nil")")
        print("   - 场景置信度: \(result.sceneConfidence ?? 0)")
        
        return result
    }
    
    // MARK: - 技能相关 API
    
    /// 获取技能详情（包含 SKILL.md 内容）
    // 获取技能列表
    func getSkillsList(
        category: String? = nil,
        enabled: Bool = true
    ) async throws -> SkillListResponse {
        // 检查是否有 token
        let token = getAuthToken()
        guard !token.isEmpty else {
            print("⚠️ [NetworkManager] 未登录，无法获取技能列表")
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"]
            )
        }
        
        var parameters: [String: Any] = [
            "enabled": enabled
        ]
        
        if let category = category {
            parameters["category"] = category
        }
        
        let response = await AF.request(
            "\(baseURL)/skills",
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(token)"
            ],
            requestModifier: { $0.timeoutInterval = 30 }
        )
        .serializingDecodable(APIResponse<SkillListResponse>.self)
        .response
        
        return try handleResponse(response, expectedType: SkillListResponse.self)
    }
    
    func getSkillDetail(skillId: String, includeContent: Bool = true) async throws -> SkillDetailResponse {
        // 检查是否有 token
        let token = getAuthToken()
        guard !token.isEmpty else {
            print("⚠️ [NetworkManager] 未登录，无法获取技能详情")
            throw NSError(
                domain: "NetworkError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录，请先登录"]
            )
        }
        
        let url = "\(baseURL)/skills/\(skillId)"
        var components = URLComponents(string: url)
        if includeContent {
            components?.queryItems = [URLQueryItem(name: "include_content", value: "true")]
        }
        
        guard let finalURL = components?.url else {
            throw NSError(
                domain: "NetworkError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "无效的 URL"]
            )
        }
        
        let response = await AF.request(
            finalURL,
            method: .get,
            headers: [
                "Authorization": "Bearer \(token)"
            ]
        )
        .serializingDecodable(APIResponse<SkillDetailResponse>.self)
        .response
        
        return try handleResponse(response, expectedType: SkillDetailResponse.self)
    }
}

// 图片 URL 转换工具
// 由于 OSS bucket 是私有的，需要将 OSS URL 转换为后端 API URL
extension VisualData {
    /// 获取可访问的图片 URL
    /// 如果 imageUrl 是 OSS URL，转换为后端 API URL
    /// 如果 imageUrl 是后端 API URL，直接返回
    /// 如果没有 imageUrl，返回 nil
    func getAccessibleImageURL(baseURL: String) -> String? {
        guard let imageUrl = imageUrl else {
            print("⚠️ [VisualData] imageUrl 为 nil")
            return nil
        }
        
        print("🔄 [VisualData] 转换图片 URL:")
        print("  原始 URL: \(imageUrl)")
        print("  baseURL: \(baseURL)")
        
        // 如果已经是后端 API URL，直接返回
        if imageUrl.contains("/api/v1/images/") {
            print("✅ [VisualData] 已经是后端 API URL，直接返回")
            return imageUrl
        }
        
        // 如果是 OSS URL，提取 session_id 和 image_index，转换为后端 API URL
        // OSS URL 格式: https://geminipicture2.oss-cn-beijing.aliyuncs.com/images/{session_id}/{image_index}.png
        // 后端 API URL 格式: {baseURL}/images/{session_id}/{image_index}
        if imageUrl.contains("oss-cn-beijing.aliyuncs.com/images/") {
            // 提取路径部分: images/{session_id}/{image_index}.png
            if let pathRange = imageUrl.range(of: "/images/") {
                let path = String(imageUrl[pathRange.upperBound...])
                // 移除 .png 后缀
                let pathWithoutExtension = path.replacingOccurrences(of: ".png", with: "")
                let convertedURL = "\(baseURL)/images/\(pathWithoutExtension)"
                print("✅ [VisualData] OSS URL 转换成功:")
                print("  转换后 URL: \(convertedURL)")
                return convertedURL
            }
        }
        
        // 如果无法转换，返回原始 URL（可能会失败，但至少尝试）
        print("⚠️ [VisualData] 无法识别 URL 格式，返回原始 URL")
        return imageUrl
    }
}


