import SwiftUI

// 关键时刻图片轮播视图
struct VisualMomentCarouselView: View {
    let visualMoments: [VisualData]
    let baseURL: String
    
    @State private var currentIndex: Int = 0
    
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
                // 图片轮播区域
                TabView(selection: $currentIndex) {
                    ForEach(Array(visualMoments.enumerated()), id: \.element.id) { index, moment in
                        VisualMomentCardView(
                            moment: moment,
                            baseURL: baseURL,
                            index: index + 1,
                            total: visualMoments.count
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                .frame(height: 183.61)
                .onAppear {
                    // 设置页面指示器样式
                    UIPageControl.appearance().currentPageIndicatorTintColor = .systemBlue
                    UIPageControl.appearance().pageIndicatorTintColor = .systemGray
                }
            }
        }
    }
}

// 单个关键时刻卡片视图
struct VisualMomentCardView: View {
    let moment: VisualData
    let baseURL: String
    let index: Int
    let total: Int
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#F3F4F6"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#D1D5DC"), lineWidth: 1.38)
                )
            
            // 图片
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
}

// 扩展 Color 支持 hex 颜色
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
