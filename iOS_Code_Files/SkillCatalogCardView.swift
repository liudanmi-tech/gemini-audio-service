//
//  SkillCatalogCardView.swift
//  WorkSurvivalGuide
//

import SwiftUI

// MARK: - 带缓存的技能封面图
/// 接入 ImageCacheManager（内存+磁盘），切换 Tab 时缓存命中直接渲染，无 spinner
/// 所有磁盘 I/O 和网络请求在后台线程执行，不阻塞主线程
/// 按 maxDisplayDimension 降采样解码，内存比 UIImage(data:) 少 5-10x
struct SkillCoverImage: View {
    let url: URL
    /// 最大显示尺寸 pt：卡片传 180，详情页传 420
    var maxDisplayDimension: CGFloat = 420

    @State private var uiImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if isLoading {
                ProgressView().tint(.white).scaleEffect(0.7)
            }
            // 失败时为空，背景渐变透出
        }
        .onAppear(perform: load)
    }

    private func load() {
        guard uiImage == nil else { return }
        let key = "\(url.absoluteString)@\(Int(maxDisplayDimension))"
        let targetURL = url
        let dim = maxDisplayDimension
        // UIScreen.main 必须在主线程访问，在 dispatch 前提前捕获
        let scale = UIScreen.main.scale

        // 磁盘读写和网络请求全部在后台线程，避免阻塞主线程导致切 Tab 卡顿
        DispatchQueue.global(qos: .userInitiated).async {
            // 内存/磁盘缓存命中 → 回主线程直接渲染
            if let cached = ImageCacheManager.shared.image(for: key) {
                DispatchQueue.main.async { self.uiImage = cached; self.isLoading = false }
                return
            }
            // 网络加载 + 降采样解码
            URLSession.shared.dataTask(with: targetURL) { data, _, _ in
                guard let data else {
                    DispatchQueue.main.async { self.isLoading = false }
                    return
                }
                let img = Self.downsample(data: data, maxDimension: dim, scale: scale)
                if let img { ImageCacheManager.shared.cache(img, for: key) }
                DispatchQueue.main.async { self.uiImage = img; self.isLoading = false }
            }.resume()
        }
    }

    /// CGImageSource 降采样：仅解码到显示所需分辨率
    /// 1024×1024 图 → 180pt卡片 → 约 200KB（vs UIImage(data:) 的 4MB）
    private static func downsample(data: Data, maxDimension: CGFloat, scale: CGFloat) -> UIImage? {
        let opts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, opts) else { return nil }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension * scale
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg, scale: scale, orientation: .up)
    }
}

struct SkillCatalogCardView: View {
    let skill: SkillCatalogItem
    let isSelected: Bool
    let isManualMode: Bool       // 手动模式才显示选择圆圈
    let onToggle: () -> Void
    let onTapCover: () -> Void

    private var baseColor: Color {
        if let hex = skill.coverColor {
            return Color(hex: hex)
        }
        return Color(hex: "#636e72")
    }

    /// 将 cover_image 文件名转为代理 URL
    private var coverProxyURL: URL? {
        guard let raw = skill.coverImage, !raw.isEmpty else { return nil }
        let filename = raw.hasPrefix("http")
            ? (URL(string: raw)?.lastPathComponent ?? raw)
            : raw.components(separatedBy: "/").last ?? raw
        return URL(string: "\(NetworkManager.shared.getBaseURL())/skills/covers/\(filename)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover area
            // 封面：渐变色占位作为尺寸锚点，图片叠在上面
            coverGradient
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                .overlay {
                    if let proxyURL = coverProxyURL {
                        // 卡片高度 120pt，传 180 提供 retina 余量，解码内存约 200KB/张
                        SkillCoverImage(url: proxyURL, maxDisplayDimension: 180)
                            .clipped()
                    }
                }
                .overlay(alignment: .topTrailing) {
                    // 手动模式：右上角勾选圆圈
                    if isManualMode {
                        Button(action: onToggle) {
                            ZStack {
                                if isSelected {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(baseColor)
                                } else {
                                    Circle()
                                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                        .padding(10)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { onTapCover() }

            // Name + description
            VStack(alignment: .leading, spacing: 4) {
                Text(skill.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let desc = skill.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                        .lineSpacing(2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    // 手动模式：已选卡片用高亮边框强调
                    isManualMode && isSelected
                        ? Color.white.opacity(0.35)
                        : Color.white.opacity(0.08),
                    lineWidth: isManualMode && isSelected ? 1.5 : 0.5
                )
        )
        .opacity(isManualMode && !isSelected ? 0.65 : 1.0)
    }

    private var coverGradient: some View {
        LinearGradient(
            colors: [
                baseColor.opacity(0.9),
                baseColor.opacity(0.5),
                baseColor.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: skillIcon)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.white.opacity(0.25))
        )
    }

    private var skillIcon: String {
        let name = skill.name
        if name.contains("管理") { return "arrow.up.arrow.down" }
        if name.contains("协作") { return "person.2" }
        if name.contains("沟通") { return "bubble.left.and.bubble.right" }
        if name.contains("冲突") { return "bolt.fill" }
        if name.contains("谈判") { return "scalemass" }
        if name.contains("汇报") { return "chart.bar.doc.horizontal" }
        if name.contains("社交") || name.contains("闲聊") { return "party.popper" }
        if name.contains("危机") { return "exclamationmark.triangle" }
        if name.contains("防御") { return "shield" }
        if name.contains("进攻") { return "flame" }
        if name.contains("建设") { return "hammer" }
        if name.contains("治愈") { return "heart" }
        if name.contains("风暴") || name.contains("脑") { return "lightbulb" }
        if name.contains("新人") || name.contains("小白") { return "graduationcap" }
        if name.contains("骨干") || name.contains("中层") { return "briefcase" }
        if name.contains("高管") || name.contains("领袖") { return "crown" }
        if name.contains("逻辑") { return "brain.head.profile" }
        if name.contains("情商") { return "heart.text.square" }
        if name.contains("影响") { return "megaphone" }
        if name.contains("情绪") { return "waveform.path.ecg" }
        if name.contains("抑郁") || name.contains("监控") { return "shield.checkered" }
        if name.contains("教育") || name.contains("引导") { return "book" }
        if name.contains("亲密") || name.contains("关系") { return "heart.circle" }
        return "sparkles"
    }
}
