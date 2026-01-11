import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()
    
    // ⚠️ 重要：修改为你的后端 API 地址
    private let baseURL = "http://localhost:8001/api/v1"
    
    private init() {}
    
    // 获取认证 Token（暂时返回空字符串，后续实现登录后添加）
    private func getAuthToken() -> String {
        return UserDefaults.standard.string(forKey: "auth_token") ?? ""
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
            ]
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
            ]
        )
        .serializingDecodable(APIResponse<UploadResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(domain: "NetworkError", code: response.code, userInfo: [NSLocalizedDescriptionKey: response.message])
        }
        
        return data
    }
}

