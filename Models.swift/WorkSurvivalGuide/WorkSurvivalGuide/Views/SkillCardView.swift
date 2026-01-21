//
//  SkillCardView.swift
//  WorkSurvivalGuide
//
//  技能卡片视图 - 按照Figma设计稿实现
//

import SwiftUI

struct SkillCardView: View {
    let skill: SkillItem
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左侧：图标和文字信息
            HStack(alignment: .center, spacing: 15.99) { // 根据Figma: gap 15.99px
                // 图标（圆形背景）
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 56, height: 56) // 根据Figma: 56x56px
                    
                    // 图标内容（根据技能类型显示不同图标）
                    Image(systemName: iconName)
                        .font(.system(size: 28))
                        .foregroundColor(iconForegroundColor)
                }
                
                // 文字信息
                VStack(alignment: .leading, spacing: 3.9984302520751953) { // 根据Figma: gap 3.99px
                    // 技能名称
                    Text(skill.name)
                        .font(.system(size: 18, weight: .bold, design: .rounded)) // Nunito 700, 18px
                        .foregroundColor(AppColors.headerText) // #5E4B35
                        .lineLimit(1)
                    
                    // 技能描述
                    if let description = skill.description {
                        Text(description)
                            .font(.system(size: 12, weight: .regular, design: .rounded)) // Nunito 400, 12px
                            .foregroundColor(AppColors.headerText.opacity(0.6)) // rgba(94, 75, 53, 0.6)
                            .lineLimit(2)
                            .lineSpacing(0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
            
            // 右侧：开关按钮
            Button(action: onToggle) {
                ZStack {
                    if isSelected {
                        // 选中状态：填充圆形
                        Circle()
                            .fill(Color(hex: "#5E7C8B")) // 根据Figma设计: #5E7C8B
                            .frame(width: 23.99, height: 23.99) // 根据Figma: 23.99x23.99px
                        
                        // 选中图标（对勾）
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        // 未选中状态：只有边框
                        Circle()
                            .stroke(AppColors.headerText.opacity(0.3), lineWidth: 1.38) // rgba(94, 75, 53, 0.3), strokeWeight 1.38px
                            .frame(width: 23.99, height: 23.99)
                    }
                }
            }
        }
        .padding(17.373191833496094) // 根据Figma: padding 17.37px
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#FFFAF5")) // 技能卡片填充颜色 #FFFAF5
        .overlay(
            RoundedRectangle(cornerRadius: 24) // 根据Figma: borderRadius 24px
                .stroke(Color(hex: "#E8DCC6"), lineWidth: 0.69) // 根据Figma: #E8DCC6, strokeWeight 0.69px
        )
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1) // 根据Figma: boxShadow
    }
    
    // 根据技能类型返回图标背景色
    private var iconBackgroundColor: Color {
        // 根据Figma设计，不同技能使用不同颜色
        // 智能摘要: #FFD59E
        // 待办提取: #A8E6CF
        // 情绪感知: #FFAAA5
        // 关键话题: #DCEDC1
        // 结构化整理: #D4A5A5
        
        // 根据技能名称或category匹配颜色
        let skillName = skill.name.lowercased()
        if skillName.contains("摘要") || skillName.contains("summary") {
            return Color(hex: "#FFD59E")
        } else if skillName.contains("待办") || skillName.contains("todo") || skillName.contains("提取") {
            return Color(hex: "#A8E6CF")
        } else if skillName.contains("情绪") || skillName.contains("emotion") || skillName.contains("感知") {
            return Color(hex: "#FFAAA5")
        } else if skillName.contains("话题") || skillName.contains("topic") || skillName.contains("关键") {
            return Color(hex: "#DCEDC1")
        } else if skillName.contains("结构") || skillName.contains("structure") || skillName.contains("整理") {
            return Color(hex: "#D4A5A5")
        }
        
        // 默认颜色
        return Color(hex: "#FFD59E")
    }
    
    // 图标前景色（根据背景色调整）
    private var iconForegroundColor: Color {
        return AppColors.headerText // #5E4B35
    }
    
    // 根据技能类型返回图标名称
    private var iconName: String {
        let skillName = skill.name.lowercased()
        if skillName.contains("摘要") || skillName.contains("summary") {
            return "doc.text.fill"
        } else if skillName.contains("待办") || skillName.contains("todo") {
            return "checklist"
        } else if skillName.contains("情绪") || skillName.contains("emotion") {
            return "heart.fill"
        } else if skillName.contains("话题") || skillName.contains("topic") {
            return "tag.fill"
        } else if skillName.contains("结构") || skillName.contains("structure") {
            return "list.bullet.rectangle.fill"
        }
        
        // 默认图标
        return "sparkles"
    }
}
