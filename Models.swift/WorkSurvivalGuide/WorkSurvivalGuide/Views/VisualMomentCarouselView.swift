import SwiftUI

// 关键时刻图片轮播视图
struct VisualMomentCarouselView: View {
    let visualMoments: [VisualData]
    let baseURL: String
    
    @State private var currentIndex: Int = 0
    @State private var showFullScreen = false
    @State private var fullScreenInitialIndex: Int = 0
    
    var body: some View {
        if visualMoments.isEmpty {
            // 如果没有关键时刻，显示占位符
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#F3F4F6"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#D1D5DC"), lineWidth: 1.38)
                )
                .overlay(
                    Text("暂无关键时刻")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
                .frame(height: 183.61)
        } else {
            VStack(spacing: 0) {
                TabView(selection: $currentIndex) {
                    ForEach(Array(visualMoments.enumerated()), id: \.element.id) { index, moment in
                        VisualMomentCardView(
                            moment: moment,
                            baseURL: baseURL,
                            index: index + 1,
                            total: visualMoments.count,
                            onTap: {
                                fullScreenInitialIndex = index
                                showFullScreen = true
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 183.61)
                .onAppear {
                    UIPageControl.appearance().currentPageIndicatorTintColor = .systemBlue
                    UIPageControl.appearance().pageIndicatorTintColor = .systemGray
                }
            }
            .fullScreenCover(isPresented: $showFullScreen) {
                let items = visualMoments.map { (imageUrl: $0.getAccessibleImageURL(baseURL: baseURL), imageBase64: $0.imageBase64) }
                FullScreenImageViewer(
                    items: items,
                    initialIndex: fullScreenInitialIndex,
                    baseURL: baseURL
                ) {
                    showFullScreen = false
                }
            }
        }
    }
}

// 单个关键时刻卡片视图 - 点击全屏，长按保存
struct VisualMomentCardView: View {
    let moment: VisualData
    let baseURL: String
    let index: Int
    let total: Int
    var onTap: (() -> Void)?
    
    var body: some View {
        Button(action: { onTap?() }) {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#F3F4F6"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#D1D5DC"), lineWidth: 1.38)
                )
            
            // 图片（ImageLoaderView 会自动带 JWT 访问 API，并支持 Base64 回退）
            if let accessibleURL = moment.getAccessibleImageURL(baseURL: baseURL) {
                ImageLoaderView(
                    imageUrl: accessibleURL,
                    imageBase64: moment.imageBase64,
                    placeholder: "加载图片 \(index)/\(total)..."
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onAppear {
                    print("🖼️ [VisualMomentCardView] 图片 \(index)/\(total):")
                    print("  原始 URL: \(moment.imageUrl ?? "nil")")
                    print("  转换后 URL: \(accessibleURL)")
                }
            } else if let b64 = moment.imageBase64, !b64.isEmpty {
                ImageLoaderView(imageUrl: nil, imageBase64: b64, placeholder: "加载中...")
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // 如果没有图片，显示提示信息和调试信息
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("暂无图片")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let originalURL = moment.imageUrl {
                        Text("原始 URL: \(originalURL)")
                            .font(.caption2)
                            .foregroundColor(.red)
                            .lineLimit(2)
                    }
                }
                .onAppear {
                    print("⚠️ [VisualMomentCardView] 图片 \(index)/\(total) 无法获取可访问 URL")
                    print("  imageUrl: \(moment.imageUrl ?? "nil")")
                    print("  imageBase64: \(moment.imageBase64 != nil ? "有数据" : "nil")")
                    print("  baseURL: \(baseURL)")
                }
            }
        }
        }
        .buttonStyle(.plain)
    }
}
