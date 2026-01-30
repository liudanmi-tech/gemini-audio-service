//
//  NetworkManager.swift
//  WorkSurvivalGuide
//
//  网络请求管理器
//

import Foundation
import Alamofire

class NetworkManager {
    static let shared = NetworkManager()
    
    // ⚠️ 重要：修改为你的后端 API 地址
    // 本地：http://localhost:8000/api/v1  服务器：80 端口经 Nginx 转发
    private let baseURL = "http://47.79.254.213/api/v1"
    
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
            ]
        )
        .serializingDecodable(APIResponse<TaskListResponse>.self)
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
    
    // 上传音频文件
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        print("🌐 [NetworkManager] ========== 上传音频 ==========")
        print("🌐 [NetworkManager] 文件路径: \(fileURL.path)")
        print("🌐 [NetworkManager] 文件是否存在: \(FileManager.default.fileExists(atPath: fileURL.path))")
        print("🌐 [NetworkManager] 使用真实 API 上传音频")
        print("🌐 [NetworkManager] API 地址: \(baseURL)/audio/upload")
        
        let uploadTask = AF.upload(
            multipartFormData: { multipartFormData in
                print("📤 [NetworkManager] 添加文件到 multipart form data")
                print("   - 文件名: \(fileURL.lastPathComponent)")
                print("   - MIME 类型: audio/m4a")
                
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
        
        // 添加上传进度监听
        uploadTask.uploadProgress { progress in
            let percentage = Int(progress.fractionCompleted * 100)
            print("📤 [NetworkManager] 上传进度: \(percentage)%")
        }
        
        // 先获取原始响应数据用于调试
        let dataTask = uploadTask.serializingData()
        
        do {
            let data = try await dataTask.value
            let httpResponse = try await dataTask.response
            
            print("📥 [NetworkManager] 收到响应")
            print("📥 [NetworkManager] 状态码: \(httpResponse.statusCode)")
            print("📥 [NetworkManager] 响应头: \(httpResponse.headers)")
            print("📥 [NetworkManager] 响应数据长度: \(data.count) 字节")
            
            if data.isEmpty {
                print("❌ [NetworkManager] 响应数据为空")
                throw NSError(
                    domain: "NetworkError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "服务器返回空响应"]
                )
            }
            
            // 打印原始响应字符串（用于调试）
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 [NetworkManager] 响应内容: \(responseString)")
            }
            
            // 尝试解析 JSON
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(APIResponse<UploadResponse>.self, from: data)
            
            print("✅ [NetworkManager] JSON 解析成功")
            print("✅ [NetworkManager] 响应码: \(apiResponse.code)")
            print("✅ [NetworkManager] 响应消息: \(apiResponse.message)")
            
            guard apiResponse.code == 200, let uploadData = apiResponse.data else {
                print("❌ [NetworkManager] 响应码不是 200 或 data 为空")
                print("❌ [NetworkManager] code: \(apiResponse.code), message: \(apiResponse.message)")
                throw NSError(
                    domain: "NetworkError",
                    code: apiResponse.code,
                    userInfo: [NSLocalizedDescriptionKey: apiResponse.message]
                )
            }
            
            print("✅ [NetworkManager] 上传成功，session_id: \(uploadData.sessionId)")
            return uploadData
            
        } catch let error as DecodingError {
            print("❌ [NetworkManager] JSON 解析失败")
            print("❌ [NetworkManager] 错误类型: DecodingError")
            print("❌ [NetworkManager] 错误详情: \(error)")
            
            // 尝试打印原始响应以便调试
            if let data = try? await dataTask.value,
               let responseString = String(data: data, encoding: .utf8) {
                print("❌ [NetworkManager] 原始响应: \(responseString)")
            }
            
            throw NSError(
                domain: "NetworkError",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "响应解析失败: \(error.localizedDescription)"]
            )
        } catch {
            print("❌ [NetworkManager] 上传失败")
            print("❌ [NetworkManager] 错误类型: \(type(of: error))")
            print("❌ [NetworkManager] 错误信息: \(error.localizedDescription)")
            throw error
        }
    }
}

