import SwiftUI

// 图片加载视图（支持 URL 和 Base64）
struct ImageLoaderView: View {
    let imageUrl: String?
    let imageBase64: String?
    let placeholder: String
    var contentMode: ContentMode = .fit
    /// 404 等加载失败时回调，供父视图切换为占位内容
    var onLoadFailed: (() -> Void)?
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    init(imageUrl: String?, imageBase64: String?, placeholder: String = "加载中...", contentMode: ContentMode = .fit, onLoadFailed: (() -> Void)? = nil) {
        self.imageUrl = imageUrl
        self.imageBase64 = imageBase64
        self.placeholder = placeholder
        self.contentMode = contentMode
        self.onLoadFailed = onLoadFailed
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            } else if isLoading {
                ProgressView(placeholder)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if loadError != nil {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("图片加载失败")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("无图片")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // 优先检查本地缓存
        if let url = imageUrl, let cached = ImageCacheManager.shared.image(for: url) {
            image = cached
            isLoading = false
            return
        }
        if let b64 = imageBase64, !b64.isEmpty, let cached = ImageCacheManager.shared.image(forBase64: b64) {
            image = cached
            isLoading = false
            return
        }
        if let imageUrl = imageUrl {
            loadImageFromURL(imageUrl)
        } else if let imageBase64 = imageBase64 {
            loadImageFromBase64(imageBase64)
        } else {
            isLoading = false
        }
    }
    
    private func loadImageFromURL(_ urlString: String) {
        print("🖼️ [ImageLoaderView] 开始加载图片: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "ImageLoaderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 URL: \(urlString)"])
            print("❌ [ImageLoaderView] URL 无效: \(urlString)")
            loadError = error
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 90  // 图片从 OSS 拉取可能较慢，90 秒
        request.allowsConstrainedNetworkAccess = true
        request.allowsExpensiveNetworkAccess = true
        
        // 图片 API 需要 JWT，对 /api/v1/images/ 等后端 API 添加 Authorization
        if urlString.contains("/api/v1/"), let token = KeychainManager.shared.getToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ImageLoaderView] 网络错误: \(error.localizedDescription)")
                    // 超时/网络失败时若有 Base64 则回退
                    if let b64 = self.imageBase64, !b64.isEmpty {
                        self.loadImageFromBase64(b64)
                        return
                    }
                    self.loadError = error
                    self.isLoading = false
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 [ImageLoaderView] HTTP 状态码: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        // URL 失败（如 401、404）时尝试 Base64 回退
                        if let b64 = self.imageBase64, !b64.isEmpty {
                            DispatchQueue.main.async { self.loadImageFromBase64(b64) }
                            return
                        }
                        let error = NSError(domain: "ImageLoaderError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                        print("❌ [ImageLoaderView] HTTP 错误: \(httpResponse.statusCode)")
                        self.loadError = error
                        self.isLoading = false
                        // 404 等失败时通知父视图，便于切换为占位内容
                        if httpResponse.statusCode == 404 || httpResponse.statusCode >= 500 {
                            self.onLoadFailed?()
                        }
                        return
                    }
                }
                
                guard let data = data else {
                    let error = NSError(domain: "ImageLoaderError", code: -2, userInfo: [NSLocalizedDescriptionKey: "响应数据为空"])
                    print("❌ [ImageLoaderView] 响应数据为空")
                    self.loadError = error
                    self.isLoading = false
                    return
                }
                
                print("✅ [ImageLoaderView] 收到数据，大小: \(data.count) 字节")
                
                guard let uiImage = UIImage(data: data) else {
                    let error = NSError(domain: "ImageLoaderError", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据，数据大小: \(data.count) 字节"])
                    print("❌ [ImageLoaderView] 无法解析图片数据")
                    self.loadError = error
                    self.isLoading = false
                    return
                }
                
                print("✅ [ImageLoaderView] 图片加载成功，尺寸: \(uiImage.size)")
                self.image = uiImage
                self.isLoading = false
                ImageCacheManager.shared.cache(uiImage, for: urlString)
            }
        }.resume()
    }
    
    private func loadImageFromBase64(_ base64String: String) {
        guard let data = Data(base64Encoded: base64String),
              let uiImage = UIImage(data: data) else {
            loadError = NSError(domain: "ImageLoaderError", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法解析 Base64 图片"])
            isLoading = false
            return
        }
        
        image = uiImage
        isLoading = false
        ImageCacheManager.shared.cache(uiImage, forBase64: base64String)
    }
}
