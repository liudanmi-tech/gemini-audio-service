//
//  AuthService.swift
//  WorkSurvivalGuide
//
//  认证服务，处理登录和验证码相关API
//

import Foundation
import Alamofire

class AuthService {
    static let shared = AuthService()
    
    private let baseURL = "http://47.79.254.213:8001/api/v1"
    
    private init() {}
    
    // 发送验证码
    func sendVerificationCode(phone: String) async throws -> SendCodeResponse {
        let response = try await AF.request(
            "\(baseURL)/auth/send-code",
            method: .post,
            parameters: ["phone": phone],
            encoding: JSONEncoding.default,
            headers: ["Content-Type": "application/json"]
        )
        .serializingDecodable(APIResponse<SendCodeResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "AuthError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        return data
    }
    
    // 登录
    func login(phone: String, code: String) async throws -> LoginResponse {
        let response = try await AF.request(
            "\(baseURL)/auth/login",
            method: .post,
            parameters: [
                "phone": phone,
                "code": code
            ],
            encoding: JSONEncoding.default,
            headers: ["Content-Type": "application/json"]
        )
        .serializingDecodable(APIResponse<LoginResponse>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "AuthError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        // 保存Token和用户ID到Keychain
        _ = KeychainManager.shared.saveToken(data.token)
        _ = KeychainManager.shared.saveUserID(data.user_id)
        
        return data
    }
    
    // 获取当前用户信息
    func getCurrentUser() async throws -> UserInfo {
        guard let token = KeychainManager.shared.getToken() else {
            throw NSError(
                domain: "AuthError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录"]
            )
        }
        
        let response = try await AF.request(
            "\(baseURL)/auth/me",
            method: .get,
            headers: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ]
        )
        .serializingDecodable(APIResponse<UserInfo>.self)
        .value
        
        guard response.code == 200, let data = response.data else {
            throw NSError(
                domain: "AuthError",
                code: response.code,
                userInfo: [NSLocalizedDescriptionKey: response.message]
            )
        }
        
        return data
    }
    
    // 登出
    func logout() {
        KeychainManager.shared.clearAll()
    }
}

// MARK: - Response Models

struct SendCodeResponse: Codable {
    let phone: String
    let code: String?
}

struct LoginResponse: Codable {
    let token: String
    let user_id: String
    let expires_in: Int
}

struct UserInfo: Codable {
    let user_id: String
    let phone: String
    let created_at: String
    let last_login_at: String?
}
