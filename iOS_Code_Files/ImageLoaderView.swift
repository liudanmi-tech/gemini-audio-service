import SwiftUI
import Combine

// 图片加载视图（支持 URL 和 Base64）
struct ImageLoaderView: View {
    let imageUrl: String?
    let imageBase64: String?
    let placeholder: String
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    init(imageUrl: String?, imageBase64: String?, placeholder: String = "加载中...") {
        self.imageUrl = imageUrl
        self.imageBase64 = imageBase64
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
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
        // 优先使用 imageUrl
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
        request.timeoutInterval = 30  // 设置超时时间
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ [ImageLoaderView] 网络错误: \(error.localizedDescription)")
                    self.loadError = error
                    self.isLoading = false
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 [ImageLoaderView] HTTP 状态码: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        let error = NSError(domain: "ImageLoaderError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                        print("❌ [ImageLoaderView] HTTP 错误: \(httpResponse.statusCode)")
                        self.loadError = error
                        self.isLoading = false
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
    }
}
