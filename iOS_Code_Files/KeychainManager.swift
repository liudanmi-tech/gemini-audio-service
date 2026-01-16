//
//  KeychainManager.swift
//  WorkSurvivalGuide
//
//  Keychain管理器，用于安全存储JWT Token
//

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.worksurvivalguide.auth"
    private let tokenKey = "jwt_token"
    private let userIDKey = "user_id"
    
    private init() {}
    
    // 保存Token
    func saveToken(_ token: String) -> Bool {
        return save(key: tokenKey, value: token)
    }
    
    // 获取Token
    func getToken() -> String? {
        return get(key: tokenKey)
    }
    
    // 删除Token
    func deleteToken() -> Bool {
        return delete(key: tokenKey)
    }
    
    // 保存用户ID
    func saveUserID(_ userID: String) -> Bool {
        return save(key: userIDKey, value: userID)
    }
    
    // 获取用户ID
    func getUserID() -> String? {
        return get(key: userIDKey)
    }
    
    // 删除用户ID
    func deleteUserID() -> Bool {
        return delete(key: userIDKey)
    }
    
    // 清除所有认证信息
    func clearAll() {
        _ = deleteToken()
        _ = deleteUserID()
    }
    
    // 检查是否已登录
    func isLoggedIn() -> Bool {
        return getToken() != nil
    }
    
    // MARK: - Private Methods
    
    private func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        // 先删除旧值
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    private func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
