//
//  SkillDetailSheet.swift
//  WorkSurvivalGuide
//

import SwiftUI

struct SkillDetailSheet: View {
    let skill: SkillCatalogItem
    let isSelected: Bool
    let onToggle: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var baseColor: Color {
        Color(hex: skill.coverColor ?? "#636e72")
    }

    private var gradientCover: some View {
        LinearGradient(
            colors: [baseColor.opacity(0.85), baseColor.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 将 cover_image（文件名或完整 URL）转为可访问的代理 URL
    private var coverProxyURL: URL? {
        guard let raw = skill.coverImage, !raw.isEmpty else { return nil }
        let filename = raw.hasPrefix("http")
            ? (URL(string: raw)?.lastPathComponent ?? raw)
            : raw.components(separatedBy: "/").last ?? raw
        let base = NetworkManager.shared.getBaseURL()
        return URL(string: "\(base)/skills/covers/\(filename)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Hero 封面图（有 cover_image 显示生成图，否则显示渐变色占位）──
                    ZStack(alignment: .bottomLeading) {
                        if let proxyURL = coverProxyURL {
                            AsyncImage(url: proxyURL) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable()
                                        .aspectRatio(contentMode: .fill)
                                case .failure:
                                    gradientCover
                                default:
                                    gradientCover
                                        .overlay(ProgressView().tint(.white))
                                }
                            }
                            .frame(height: 210)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        } else {
                            gradientCover
                                .frame(height: 210)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        // Tagline 叠加在封面底部
                        if let tagline = skill.proContent?.tagline {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.55)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            Text("「\(tagline)」")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)
                                .shadow(radius: 3)
                        }
                    }
                    .frame(height: 210)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // ── 技能名称 + 简介 ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text(skill.name)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if let desc = skill.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 15, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(5)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    if let pro = skill.proContent {
                        // ── 理论基础（书单）──
                        if let books = pro.books, !books.isEmpty {
                            ProSection(icon: "books.vertical.fill", iconColor: Color(hex: "#A29BFE"), title: "理论基础") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(books, id: \.self) { book in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text("📖")
                                                .font(.system(size: 14))
                                            Text(book)
                                                .font(.system(size: 14, design: .rounded))
                                                .foregroundColor(.white.opacity(0.85))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }

                        // ── 数据支撑 ──
                        if let research = pro.research, !research.isEmpty {
                            ProSection(icon: "chart.bar.fill", iconColor: Color(hex: "#00B894"), title: "数据支撑") {
                                Text(research)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // ── 真实案例 ──
                        if let cs = pro.casestudy, !cs.isEmpty {
                            ProSection(icon: "person.fill.checkmark", iconColor: Color(hex: "#FDCB6E"), title: "真实案例") {
                                Text(cs)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        // ── 已验证效果 ──
                        if let effects = pro.effects, !effects.isEmpty {
                            ProSection(icon: "checkmark.seal.fill", iconColor: baseColor, title: "已验证效果") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(effects, id: \.self) { effect in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "arrow.up.right.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(baseColor)
                                            Text(effect)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.9))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                Button(action: {
                    onToggle()
                    dismiss()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 18))
                        Text(isSelected ? "取消选择" : "选择此技能")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Color(white: 0.3) : baseColor)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

// MARK: - 专业内容区块容器

private struct ProSection<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            content()
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.07), lineWidth: 0.5)
                        )
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}
