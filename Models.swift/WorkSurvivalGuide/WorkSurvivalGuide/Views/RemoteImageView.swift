//
//  RemoteImageView.swift
//  WorkSurvivalGuide
//
//  远程图片加载视图 - 用于加载OSS图片
//

import SwiftUI

struct RemoteImageView: View {
    let url: URL?
    let placeholder: AnyView
    let errorView: AnyView
    let width: CGFloat
    let height: CGFloat
    
    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var loadError: Error?
    @State private var lastLoadedURL: URL?
    
    init(
        url: URL?,
        placeholder: AnyView = AnyView(Circle().fill(Color.gray.opacity(0.2))),
        errorView: AnyView? = nil,
        width: CGFloat = 120,
        height: CGFloat = 120
    ) {
        self.url = url
        self.placeholder = placeholder
        self.errorView = errorView ?? AnyView(
            Circle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                )
        )
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(Circle())
            } else if isLoading {
                placeholder
                    .frame(width: width, height: height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.8)
                    )
            } else if loadError != nil {
                errorView
                    .frame(width: width, height: height)
            } else {
                placeholder
                    .frame(width: width, height: height)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: url) { _ in
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let url = url else {
            print("❌ [RemoteImageView] URL为空")
            return
        }
        
        // 检查URL是否变化
        if let lastURL = lastLoadedURL, lastURL == url, image != nil && !isLoading {
            print("📷 [RemoteImageView] URL未变化且已有图片，跳过加载: \(url.absoluteString)")
            return
        }
        
        // URL变化或没有图片，需要重新加载
        if lastLoadedURL != url {
            print("📷 [RemoteImageView] URL已变化，清除旧图片")
            print("   旧URL: \(lastLoadedURL?.absoluteString ?? "nil")")
            print("   新URL: \(url.absoluteString)")
            image = nil
            loadError = nil
        }
        
        isLoading = true
        loadError = nil
        lastLoadedURL = url
        
        print("📷 [RemoteImageView] 开始加载图片: \(url.absoluteString)")
        
        Task {
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 60
                if url.absoluteString.contains("/api/v1/"), let token = KeychainManager.shared.getToken(), !token.isEmpty {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "RemoteImageView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的HTTP响应"])
                }
                
                guard httpResponse.statusCode == 200 else {
                    throw NSError(domain: "RemoteImageView", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                }
                
                guard let loadedImage = UIImage(data: data) else {
                    throw NSError(domain: "RemoteImageView", code: -2, userInfo: [NSLocalizedDescriptionKey: "无法解析图片数据"])
                }
                
                await MainActor.run {
                    self.image = loadedImage
                    self.isLoading = false
                    print("✅ [RemoteImageView] 图片加载成功: \(url.absoluteString)")
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                    print("❌ [RemoteImageView] 图片加载失败: \(url.absoluteString)")
                    print("   错误: \(error.localizedDescription)")
                    if let nsError = error as NSError? {
                        print("   错误代码: \(nsError.code)")
                        print("   错误域: \(nsError.domain)")
                    }
                }
            }
        }
    }
}
