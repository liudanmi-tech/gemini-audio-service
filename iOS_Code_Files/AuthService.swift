//
//  AuthService.swift
//  WorkSurvivalGuide
//
//  认证服务：邮箱+密码、Apple Sign In、手机号（旧接口保留）
//

import Foundation
import Alamofire

class AuthService {
    static let shared = AuthService()

    private let config = AppConfig.shared
    private var baseURLForWrite: String { config.writeBaseURL }

    private init() {}

    // MARK: - Email Login / Register (合一)

    func emailLogin(email: String, password: String) async throws -> LoginResponse {
        let dataResponse = await AF.request(
            "\(baseURLForWrite)/auth/email-login",
            method: .post,
            parameters: ["email": email, "password": password],
            encoding: JSONEncoding.default,
            headers: ["Content-Type": "application/json"],
            requestModifier: { $0.timeoutInterval = 30 }
        )
        .serializingData()
        .response

        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()

        if statusCode == 200 {
            let decoded = try JSONDecoder().decode(APIResponse<LoginResponse>.self, from: responseData)
            guard decoded.code == 200, let data = decoded.data else {
                throw NSError(domain: "AuthError", code: decoded.code,
                              userInfo: [NSLocalizedDescriptionKey: decoded.message])
            }
            _ = KeychainManager.shared.saveToken(data.token)
            _ = KeychainManager.shared.saveUserID(data.user_id)
            return data
        }
        let msg = Self.parseFastAPIErrorDetail(responseData) ?? "Login failed"
        throw NSError(domain: "AuthError", code: statusCode,
                      userInfo: [NSLocalizedDescriptionKey: msg])
    }

    // MARK: - Apple Sign In

    func appleLogin(identityToken: String, authCode: String, fullName: String?) async throws -> LoginResponse {
        var params: [String: Any] = [
            "identity_token": identityToken,
            "authorization_code": authCode
        ]
        if let name = fullName { params["full_name"] = name }

        let dataResponse = await AF.request(
            "\(baseURLForWrite)/auth/apple-login",
            method: .post,
            parameters: params,
            encoding: JSONEncoding.default,
            headers: ["Content-Type": "application/json"],
            requestModifier: { $0.timeoutInterval = 30 }
        )
        .serializingData()
        .response

        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()

        if statusCode == 200 {
            let decoded = try JSONDecoder().decode(APIResponse<LoginResponse>.self, from: responseData)
            guard decoded.code == 200, let data = decoded.data else {
                throw NSError(domain: "AuthError", code: decoded.code,
                              userInfo: [NSLocalizedDescriptionKey: decoded.message])
            }
            _ = KeychainManager.shared.saveToken(data.token)
            _ = KeychainManager.shared.saveUserID(data.user_id)
            return data
        }
        let msg = Self.parseFastAPIErrorDetail(responseData) ?? "Apple Sign In failed"
        throw NSError(domain: "AuthError", code: statusCode,
                      userInfo: [NSLocalizedDescriptionKey: msg])
    }

    // MARK: - Get Current User

    func getCurrentUser() async throws -> UserInfo {
        guard let token = KeychainManager.shared.getToken() else {
            throw NSError(domain: "AuthError", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Not logged in"])
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
            let msg = Self.parseFastAPIErrorDetail(responseData) ?? "Failed to get user info"
            throw NSError(domain: "AuthError", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let decoded = try JSONDecoder().decode(APIResponse<UserInfo>.self, from: responseData)
        guard decoded.code == 200, let data = decoded.data else {
            throw NSError(domain: "AuthError", code: decoded.code,
                          userInfo: [NSLocalizedDescriptionKey: decoded.message])
        }
        return data
    }

    // MARK: - Logout

    func logout() {
        KeychainManager.shared.clearAll()
    }

    // MARK: - Legacy: Phone + SMS (保留旧接口，不在新 UI 使用)

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
                throw NSError(domain: "AuthError", code: decoded.code,
                              userInfo: [NSLocalizedDescriptionKey: decoded.message])
            }
            return data
        }
        let msg = Self.parseFastAPIErrorDetail(responseData) ?? "Failed to send code"
        throw NSError(domain: "AuthError", code: statusCode,
                      userInfo: [NSLocalizedDescriptionKey: msg])
    }

    func login(phone: String, code: String) async throws -> LoginResponse {
        let dataResponse = await AF.request(
            "\(baseURLForWrite)/auth/login",
            method: .post,
            parameters: ["phone": phone, "code": code],
            encoding: JSONEncoding.default,
            headers: ["Content-Type": "application/json"]
        )
        .serializingData()
        .response

        let statusCode = dataResponse.response?.statusCode ?? 0
        let responseData = dataResponse.data ?? Data()

        if statusCode == 200 {
            let decoded = try JSONDecoder().decode(APIResponse<LoginResponse>.self, from: responseData)
            guard decoded.code == 200, let loginData = decoded.data else {
                throw NSError(domain: "AuthError", code: decoded.code,
                              userInfo: [NSLocalizedDescriptionKey: decoded.message])
            }
            _ = KeychainManager.shared.saveToken(loginData.token)
            _ = KeychainManager.shared.saveUserID(loginData.user_id)
            return loginData
        }
        let msg = Self.parseFastAPIErrorDetail(responseData) ?? "Login failed"
        throw NSError(domain: "AuthError", code: statusCode,
                      userInfo: [NSLocalizedDescriptionKey: msg])
    }

    // MARK: - Helpers

    private static func parseFastAPIErrorDetail(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = json["detail"] else { return nil }
        if let str = detail as? String { return str }
        if let arr = detail as? [[String: Any]], let first = arr.first,
           let msg = first["msg"] as? String { return msg }
        return nil
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
    let expires_in: Int?
    var expiresInSeconds: Int { expires_in ?? (24 * 3600) }
}

struct UserInfo: Codable {
    let user_id: String
    let phone: String?
    let email: String?
    let created_at: String?
    let last_login_at: String?
}
