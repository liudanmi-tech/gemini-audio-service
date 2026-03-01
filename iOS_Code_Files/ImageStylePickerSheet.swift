//
//  ImageStylePickerSheet.swift
//  WorkSurvivalGuide
//
//  图片风格选择弹窗 - 展示 14 种风格示例，选择后影响新生成的策略图片
//

import SwiftUI

struct ImageStylePickerSheet: View {
    @Binding var selectedStyleId: String
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ImageStylePresets.all) { style in
                        StyleCard(
                            style: style,
                            isSelected: selectedStyleId == style.id
                        ) {
                            selectedStyleId = style.id
                            UserDefaults.standard.set(style.id, forKey: "image_style")
                            Task { await NetworkManager.shared.updateUserPreferences(imageStyle: style.id) }
                            dismiss()
                        }
                    }
                }
                .padding(16)
            }
            .background(AppColors.cardBackground)
            .navigationTitle("图片风格")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.headerText)
                }
            }
        }
    }
}

private struct StyleCard: View {
    let style: ImageStyle
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                StyleThumbnailView(styleId: style.id, accentColor: style.accentColor)
                    .aspectRatio(4/3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )

                Text(style.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)
            }
            .padding(8)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 风格缩略图：渐变色为底，图片加载成功后覆盖；使用 ImageCacheManager 缓存，反复打开不闪烁
private struct StyleThumbnailView: View {
    let styleId: String
    let accentColor: Color

    @State private var loadedImage: UIImage?

    private var thumbnailURL: String {
        let base = NetworkManager.shared.getBaseURL()
        let apiBase = base.hasSuffix("/api/v1") ? String(base.dropLast(7)) : base
        return "\(apiBase)/api/v1/style-thumbnails/\(styleId)"
    }

    var body: some View {
        ZStack {
            // 渐变色底：始终存在，加载中和无缩略图时作为最终展示
            LinearGradient(
                colors: [accentColor, accentColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 图片层：加载成功后无动画覆盖渐变
            if let img = loadedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            }
        }
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        guard loadedImage == nil else { return }
        let url = thumbnailURL
        // 命中内存缓存直接显示，无网络请求
        if let cached = ImageCacheManager.shared.image(for: url) {
            loadedImage = cached
            return
        }
        // 缓存未命中：后台下载，降采样后写缓存（节省内存）
        guard let requestURL = URL(string: url) else { return }
        URLSession.shared.dataTask(with: requestURL) { data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            ImageCacheManager.shared.cache(img, for: url)
            DispatchQueue.main.async { loadedImage = img }
        }.resume()
    }
}
