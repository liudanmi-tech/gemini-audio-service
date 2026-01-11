//
//  DialogueReviewView.swift
//  WorkSurvivalGuide
//
//  对话复盘组件 - 按照Figma设计稿实现（带总结和展开按钮）
//

import SwiftUI

struct DialogueReviewView: View {
    let summary: String?
    let dialogues: [DialogueItem]
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            Text("对话复盘")
                .font(AppFonts.cardTitle)
                .foregroundColor(AppColors.headerText)
                .padding(.horizontal, 21.5)
                .padding(.top, 21.5)
            
            // 总结文本
            if let summary = summary, !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(AppColors.headerText.opacity(0.8))
                    .lineSpacing(4)
                    .padding(.horizontal, 21.5)
                    .padding(.bottom, 8)
            }
            
            // 显示详情按钮
            HStack {
                Spacer()
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Text("显示详情")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.headerText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                Spacer()
            }
            .padding(.bottom, isExpanded ? 0 : 21.5)
            
            // 对话列表（展开时显示）
            if isExpanded {
                VStack(spacing: 16) {
                ForEach(Array(dialogues.enumerated()), id: \.offset) { index, dialogue in
                    DialogueBubbleView(
                        dialogue: dialogue,
                        isOwn: dialogue.isMe ?? false  // 使用后端返回的is_me字段
                    )
                }
                }
                .padding(.horizontal, 21.5)
                .padding(.bottom, 21.5)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1.51)
        )
        .cornerRadius(12)
        .shadow(color: AppColors.border, radius: 0, x: 3, y: 3)
    }
}

struct DialogueBubbleView: View {
    let dialogue: DialogueItem
    let isOwn: Bool // 是否是自己说的话
    
    var body: some View {
        if isOwn {
            // 右侧：自己的对话（橙色背景）
            HStack(alignment: .top, spacing: 12) {
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    // 对话气泡
                    Text(dialogue.content)
                        .font(AppFonts.time)
                        .foregroundColor(AppColors.primaryText)
                        .padding(.horizontal, 12.69)
                        .padding(.vertical, 11.68)
                        .background(Color(hex: "#FFD59E").opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#FFD6A7"), lineWidth: 0.69)
                        )
                        .clipShape(RoundedCornerShape(radius: 16, corners: [.topLeft, .topRight, .bottomLeft]))
                    
                    // 头像
                    Circle()
                        .fill(Color(hex: "#FFD6A8"))
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#FF8904"), lineWidth: 1.38)
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Text(getSpeakerInitial(dialogue.speaker))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(AppColors.primaryText)
                        )
                }
            }
        } else {
            // 左侧：对方的对话（白色背景）
            HStack(alignment: .top, spacing: 12) {
                // 头像
                Circle()
                    .fill(Color(hex: "#BEDBFF"))
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "#51A2FF"), lineWidth: 1.38)
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(getSpeakerEmoji(dialogue.speaker))
                            .font(.system(size: 12))
                    )
                
                // 对话气泡
                Text(dialogue.content)
                    .font(AppFonts.time)
                    .foregroundColor(AppColors.primaryText)
                    .padding(.horizontal, 12.69)
                    .padding(.vertical, 11.68)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#E5E7EB"), lineWidth: 0.69)
                    )
                    .clipShape(RoundedCornerShape(radius: 16, corners: [.topRight, .bottomRight, .bottomLeft]))
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                
                Spacer()
            }
        }
    }
    
    private func getSpeakerEmoji(_ speaker: String) -> String {
        // 根据说话人返回emoji或首字母
        if speaker.contains("说话人1") || speaker.contains("Speaker1") || speaker.contains("Speaker_1") {
            return "🐮"
        } else if speaker.contains("说话人2") || speaker.contains("Speaker2") || speaker.contains("Speaker_0") {
            return "👤"
        }
        return String(speaker.prefix(1))
    }
    
    private func getSpeakerInitial(_ speaker: String) -> String {
        // 返回说话人的首字母
        if speaker.count >= 2 {
            return String(speaker.prefix(2))
        }
        return String(speaker.prefix(1))
    }
}

// 注意：cornerRadius扩展和RoundedCornerShape已在ViewExtensions.swift中定义
