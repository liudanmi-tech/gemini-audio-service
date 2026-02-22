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
                // 占位示例图
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [style.accentColor, style.accentColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Text(style.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    )
                    .aspectRatio(4/3, contentMode: .fit)
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
