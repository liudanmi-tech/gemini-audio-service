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
    
    // 获取任务列表
    func getTaskList(
        date: Date? = nil,
        status: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> TaskListResponse {
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
        
        let response = try await AF.request(
            "\(baseURL)/tasks/sessions",
            method: .get,
            parameters: parameters,
            headers: [
                "Content-Type": "application/json",
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 120 } // 设置超时时间为120秒
        )
        .serializingDecodable(APIResponse<TaskListResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(domain: "NetworkError", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.message])
        }
        
        return data
    }
    
    // 上传音频文件
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        let response = try await AF.upload(
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
                "Authorization": "Bearer \(getAuthToken())"
            ],
            requestModifier: { $0.timeoutInterval = 180 } // 上传文件可能需要更长时间，设置180秒
        )
        .serializingDecodable(APIResponse<UploadResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(domain: "NetworkError", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.message])
        }
        
        return data
    }
    
    // 获取任务详情
    func getTaskDetail(sessionId: String) async throws -> TaskDetailResponse {
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
            throw NSError(domain: "NetworkError", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.message])
        }
        
        return data
    }
    
    // 获取策略分析（包含图片）
    func getStrategyAnalysis(sessionId: String) async throws -> StrategyAnalysisResponse {
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
            throw NSError(domain: "NetworkError", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.message])
        }
        
        return data
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


