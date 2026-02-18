//
//  ImageCacheManager.swift
//  WorkSurvivalGuide
//
//  图片本地缓存 - 加载完成后缓存，避免重复加载
//

import Foundation
import UIKit
import CryptoKit

/// 图片缓存管理器：内存 + 磁盘，加载过的图片不再重复请求
final class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    /// 内存缓存（NSCache 自动处理内存压力）
    private let memoryCache = NSCache<NSString, UIImage>()
    
    /// 磁盘缓存目录
    private var diskCacheDir: URL? {
        guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    /// 磁盘缓存有效期（7 天）
    private let diskCacheMaxAge: TimeInterval = 7 * 24 * 3600
    
    private init() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 50 * 1024 * 1024  // 约 50MB
    }
    
    // MARK: - 缓存 key
    
    private func cacheKeyForURL(_ urlString: String) -> String {
        let data = Data(urlString.utf8)
        return sha256Hex(data)
    }
    
    private func cacheKeyForBase64(_ base64String: String) -> String {
        let data = Data(base64String.utf8)
        return "b64_" + sha256Hex(data)
    }
    
    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - 读缓存
    
    /// 根据 URL 获取缓存图片（先内存后磁盘）
    func image(for urlString: String) -> UIImage? {
        let key = cacheKeyForURL(urlString)
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        if let img = loadFromDisk(key: key) {
            memoryCache.setObject(img, forKey: key as NSString)
            return img
        }
        return nil
    }
    
    /// 根据 Base64 获取缓存图片
    func image(forBase64 base64String: String) -> UIImage? {
        let key = cacheKeyForBase64(base64String)
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }
        if let img = loadFromDisk(key: key) {
            memoryCache.setObject(img, forKey: key as NSString)
            return img
        }
        return nil
    }
    
    // MARK: - 写缓存
    
    /// 缓存图片（URL 来源）
    func cache(_ image: UIImage, for urlString: String) {
        let key = cacheKeyForURL(urlString)
        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)
    }
    
    /// 缓存图片（Base64 来源）
    func cache(_ image: UIImage, forBase64 base64String: String) {
        let key = cacheKeyForBase64(base64String)
        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)
    }
    
    // MARK: - 磁盘读写
    
    private func diskPath(for key: String) -> URL? {
        diskCacheDir?.appendingPathComponent(key + ".png")
    }
    
    private func loadFromDisk(key: String) -> UIImage? {
        guard let path = diskPath(for: key),
              FileManager.default.fileExists(atPath: path.path) else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path.path)
        let modDate = attrs?[.modificationDate] as? Date ?? Date.distantPast
        if Date().timeIntervalSince(modDate) > diskCacheMaxAge {
            try? FileManager.default.removeItem(at: path)
            return nil
        }
        guard let data = try? Data(contentsOf: path),
              let img = UIImage(data: data) else { return nil }
        return img
    }
    
    private func saveToDisk(image: UIImage, key: String) {
        guard let path = diskPath(for: key),
              let data = image.pngData() else { return }
        try? data.write(to: path)
    }
}
