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
        VStack(alignment: .leading, spacing: 15.99368667602539) { // 根据Figma: gap 15.99px
            // 标题区域
            HStack(alignment: .center, spacing: 11.99526596069336) { // 根据Figma: gap 11.99px
                // 图标背景
                ZStack {
                    Circle()
                        .fill(Color(hex: "#FFD59E")) // 根据Figma: #FFD59E
                        .frame(width: 39.99, height: 39.99) // 根据Figma: 39.99 x 39.99px
                    
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 19.99))
                        .foregroundColor(AppColors.headerText)
                }
                
                // 标题文字
                Text("对话总结")
                    .font(.system(size: 18, weight: .black, design: .rounded)) // Nunito 900, 18px
                    .foregroundColor(AppColors.headerText) // #5E4B35
            }
            .padding(.top, 24.68) // 根据Figma: padding top 24.68px
            .padding(.horizontal, 24.68) // 根据Figma: padding horizontal 24.68px
            
            // 总结文本容器
            if let summary = summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(summary)
                        .font(.system(size: 16, weight: .medium, design: .rounded)) // Nunito 500, 16px
                        .foregroundColor(AppColors.headerText.opacity(0.9)) // rgba(94, 75, 53, 0.9)
                        .lineSpacing(10) // 行间距改为 10px
                        .tracking(0) // 字间距设为 0
                        .frame(maxWidth: .infinity, alignment: .topLeading) // 自适应宽度
                        .fixedSize(horizontal: false, vertical: true) // 允许垂直扩展
                }
                .padding(.horizontal, 24.68)
            }
            
            // 底部按钮："查看详情 & 录音"
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 0) {
                    Spacer()
                    Text("查看详情 & 录音")
                        .font(.system(size: 14, weight: .bold, design: .rounded)) // Nunito 700, 14px
                        .foregroundColor(AppColors.headerText.opacity(0.7)) // rgba(94, 75, 53, 0.7)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15.99))
                        .foregroundColor(AppColors.headerText.opacity(0.7))
                        .padding(.leading, 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44.67) // 根据Figma: height 44.67px
                .overlay(
                    Rectangle()
                        .frame(height: 0.69)
                        .foregroundColor(AppColors.headerText.opacity(0.1)) // rgba(94, 75, 53, 0.1)
                        .offset(y: -22.335) // 顶部边框
                )
            }
            .padding(.bottom, isExpanded ? 0 : 0.69) // 根据Figma: padding bottom 0.69px
            
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
                .padding(.horizontal, 24.68)
                .padding(.bottom, 24.68)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 确保填充宽度但不超出父容器
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.2), lineWidth: 0.69)
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1) // 根据Figma: boxShadow
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
                        .background(Color.white.opacity(0.15))
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
                    .background(Color.white.opacity(0.12))
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
