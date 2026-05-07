//
//  ImageStyleRepository.swift
//  WorkSurvivalGuide
//
//  图片风格热更新仓库
//  启动时从服务器拉取 styles.json，本地缓存；网络不可用时降级到内置数据。
//

import SwiftUI
import Foundation

// 服务器返回的风格数据模型
private struct RemoteImageStyle: Codable {
    let id: String
    let name: String
    let name_en: String
    let prompt_keywords: String
    let accent_color: String
    let sort_order: Int
    let enabled: Bool
}

private struct RemoteStylesResponse: Codable {
    let code: Int
    let data: RemoteStylesData
}

private struct RemoteStylesData: Codable {
    let version: String
    let styles: [RemoteImageStyle]
    let total: Int
}

@MainActor
class ImageStyleRepository: ObservableObject {
    static let shared = ImageStyleRepository()

    /// 当前风格列表（供 UI 使用）
    @Published var styles: [ImageStyle] = ImageStylePresets.all

    private let cacheKey = "image_styles_cache_v1"
    private let cacheVersionKey = "image_styles_cache_version"

    private init() {
        loadFromCache()
    }

    // MARK: - Public

    /// 启动时调用：优先使用缓存，后台静默更新
    func fetchIfNeeded() async {
        await fetch()
    }

    // MARK: - Private

    /// 从服务器拉取风格列表并更新内存 + 缓存
    private func fetch() async {
        guard let url = buildURL() else { return }
        do {
            var request = URLRequest(url: url, timeoutInterval: 8)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let decoded = try JSONDecoder().decode(RemoteStylesResponse.self, from: data)
            guard decoded.code == 200 else { return }
            let remoteVersion = decoded.data.version
            // 版本未变时跳过（避免不必要的 UI 刷新）
            if remoteVersion == cachedVersion(), !styles.isEmpty { return }
            let newStyles = decoded.data.styles
                .filter { $0.enabled }
                .sorted { $0.sort_order < $1.sort_order }
                .map { toImageStyle($0) }
            guard !newStyles.isEmpty else { return }
            styles = newStyles
            saveToCache(data: data, version: remoteVersion)
            print("✅ [ImageStyleRepository] 风格已更新，版本 \(remoteVersion)，共 \(newStyles.count) 种")
        } catch {
            print("⚠️ [ImageStyleRepository] 拉取风格失败（使用缓存/内置）: \(error)")
        }
    }

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }
        do {
            let decoded = try JSONDecoder().decode(RemoteStylesResponse.self, from: data)
            let cached = decoded.data.styles
                .filter { $0.enabled }
                .sorted { $0.sort_order < $1.sort_order }
                .map { toImageStyle($0) }
            if !cached.isEmpty {
                styles = cached
                print("✅ [ImageStyleRepository] 从缓存加载 \(cached.count) 种风格")
            }
        } catch {
            print("⚠️ [ImageStyleRepository] 缓存解析失败: \(error)")
        }
    }

    private func saveToCache(data: Data, version: String) {
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(version, forKey: cacheVersionKey)
    }

    private func cachedVersion() -> String {
        UserDefaults.standard.string(forKey: cacheVersionKey) ?? ""
    }

    private func buildURL() -> URL? {
        // 风格列表是全局配置，固定走新加坡主节点（writeBaseURL），
        // 不走北京只读节点，避免北京节点未部署/停机时拉取失败。
        let base = AppConfig.shared.writeBaseURL
        let apiBase = base.hasSuffix("/api/v1") ? String(base.dropLast(7)) : base
        return URL(string: "\(apiBase)/api/v1/image-styles")
    }

    private func toImageStyle(_ r: RemoteImageStyle) -> ImageStyle {
        ImageStyle(
            id: r.id,
            name: r.name,
            nameEn: r.name_en,
            promptKeywords: r.prompt_keywords,
            accentColor: Color(hex: r.accent_color)
        )
    }
}
