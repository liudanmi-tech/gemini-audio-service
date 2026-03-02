//
//  SkillCatalogCardView.swift
//  WorkSurvivalGuide
//

import SwiftUI

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
            ZStack(alignment: .topTrailing) {
                // 封面：图片或渐变占位，统一由外层 frame + clipped 控制尺寸
                if let proxyURL = coverProxyURL {
                    AsyncImage(url: proxyURL) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            coverGradient
                        default:
                            coverGradient
                                .overlay(ProgressView().tint(.white).scaleEffect(0.7))
                        }
                    }
                } else {
                    coverGradient
                }

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
            .frame(height: 120)          // ← 高度统一在 ZStack 层锁定
            .clipped()                   // ← 超出部分裁掉
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
