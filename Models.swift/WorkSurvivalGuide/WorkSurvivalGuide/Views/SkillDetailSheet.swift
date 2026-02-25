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
        if let hex = skill.coverColor {
            return Color(hex: hex)
        }
        return Color(hex: "#636e72")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Video placeholder area (16:9)
                    ZStack {
                        LinearGradient(
                            colors: [baseColor.opacity(0.6), baseColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )

                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 64, height: 64)
                                Image(systemName: "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                            }
                            Text("视频介绍即将上线")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .frame(height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Skill name
                    Text(skill.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    // Description
                    if let desc = skill.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                            .lineSpacing(6)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    Spacer(minLength: 40)
                }
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                // Bottom action button
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
