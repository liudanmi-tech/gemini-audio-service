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
    
    private let config = AppConfig.shared
    private var baseURLForWrite: String { config.writeBaseURL }
    private var baseURLForRead: String { config.useBeijingRead ? config.readBaseURL : config.writeBaseURL }

    private init() {}
    
    // 发送验证码（非 200 时按 FastAPI 错误解析，避免解码失败）
    func sendVerificationCode(phone: String) async throws -> SendCodeResponse {
        let dataResponse = await AF.request(
            "\(baseURLForWrite)/auth/send-code",
            method: .post,
            parameters: ["phone": phone],
            encoding: JSONEncoding.default,
            headers: ["Content-Type": "application/json"],
            requestModifier: { $0.timeoutInterval = 30 }
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        
        if statusCode == 200 {
            let decoded = try JSONDecoder().decode(APIResponse<SendCodeResponse>.self, from: responseData)
            guard decoded.code == 200, let data = decoded.data else {
                throw NSError(
                    domain: "AuthError",
                    code: decoded.code,
                    userInfo: [NSLocalizedDescriptionKey: decoded.message]
                )
            }
            return data
        }
        let message: String
        if statusCode >= 500 {
            message = Self.parseFastAPIErrorDetail(responseData) ?? "服务器繁忙，请稍后重试"
        } else {
            message = Self.parseFastAPIErrorDetail(responseData) ?? "发送验证码失败"
        }
        throw NSError(domain: "AuthError", code: statusCode, userInfo: [NSLocalizedDescriptionKey: message])
    }
    
    // 登录（先取原始响应，再按状态码解码，避免 4xx 时 FastAPI 返回 detail 导致解码失败）
    func login(phone: String, code: String) async throws -> LoginResponse {
        let dataResponse = await AF.request(
            "\(baseURLForWrite)/auth/login",
            method: .post,
            parameters: [
                "phone": phone,
                "code": code
            ],
            encoding: JSONEncoding.default,
            headers: ["Content-Type": "application/json"]
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        
        if statusCode == 200 {
            guard !responseData.isEmpty else {
                throw NSError(
                    domain: "AuthError",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "服务器返回为空，请检查网络或稍后重试"]
                )
            }
            do {
                let decoded = try JSONDecoder().decode(APIResponse<LoginResponse>.self, from: responseData)
                guard decoded.code == 200, let loginData = decoded.data else {
                    throw NSError(
                        domain: "AuthError",
                        code: decoded.code,
                        userInfo: [NSLocalizedDescriptionKey: decoded.message]
                    )
                }
                _ = KeychainManager.shared.saveToken(loginData.token)
                _ = KeychainManager.shared.saveUserID(loginData.user_id)
                return loginData
            } catch {
                throw NSError(
                    domain: "AuthError",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "服务器返回格式异常，请稍后重试"]
                )
            }
        }
        
        // 4xx/5xx：解析 FastAPI 错误（detail 可能是字符串或数组）
        let message = Self.parseFastAPIErrorDetail(responseData) ?? "登录失败，请检查手机号和验证码"
        throw NSError(
            domain: "AuthError",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
    
    /// 从 FastAPI 错误响应中解析出可读文案（detail 为 String 或 [{"msg": "..."}]）
    private static func parseFastAPIErrorDetail(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] else { return nil }
        if let str = detail as? String { return str }
        if let arr = detail as? [[String: Any]], let first = arr.first, let msg = first["msg"] as? String {
            return msg
        }
        return nil
    }
    
    // 获取当前用户信息（先取原始响应再解码，避免 4xx/格式异常时直接抛解码错误）
    // 使用 writeBaseURL（新加坡）：/auth/me 属于认证流程，与登录同源可避免北京节点不可达时失败
    func getCurrentUser() async throws -> UserInfo {
        guard let token = KeychainManager.shared.getToken() else {
            throw NSError(
                domain: "AuthError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "未登录"]
            )
        }
        
        let dataResponse = await AF.request(
            "\(baseURLForWrite)/auth/me",
            method: .get,
            headers: [
                "Authorization": "Bearer \(token)",
                "Content-Type": "application/json"
            ],
            requestModifier: { $0.timeoutInterval = 120 }
        )
        .serializingData()
        .response
        
        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()
        
        guard statusCode == 200 else {
            let message = Self.parseFastAPIErrorDetail(responseData) ?? "获取用户信息失败"
            throw NSError(
                domain: "AuthError",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
        
        guard !responseData.isEmpty else {
            throw NSError(
                domain: "AuthError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "服务器返回为空"]
            )
        }
        
        do {
            let decoded = try JSONDecoder().decode(APIResponse<UserInfo>.self, from: responseData)
            guard decoded.code == 200, let data = decoded.data else {
                throw NSError(
                    domain: "AuthError",
                    code: decoded.code,
                    userInfo: [NSLocalizedDescriptionKey: decoded.message]
                )
            }
            return data
        } catch {
            throw NSError(
                domain: "AuthError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "服务器返回格式异常，请重新登录"]
            )
        }
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
    /// 可选，服务端若未返回则用默认值
    let expires_in: Int?
    
    var expiresInSeconds: Int { expires_in ?? (24 * 3600) }
}

struct UserInfo: Codable {
    let user_id: String
    let phone: String
    /// 服务端可能为 null（如旧数据），改为可选避免解码失败
    let created_at: String?
    let last_login_at: String?
}
