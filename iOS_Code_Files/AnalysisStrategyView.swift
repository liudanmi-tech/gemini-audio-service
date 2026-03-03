//
//  AnalysisStrategyView.swift
//  WorkSurvivalGuide
//
//  回放分析与策略组件 - 按照Figma设计稿实现
//

import SwiftUI

struct AnalysisStrategyView: View {
    let sceneDescription: String
    let strategyAnalysis: StrategyAnalysis?
    @State private var selectedStrategy: StrategyType?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题（深色背景）
            Text("Analysis & Strategy")
                .font(AppFonts.cardTitle)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15.99)
                .padding(.vertical, 15.37)
                .background(Color.white.opacity(0.15))
            
            VStack(alignment: .leading, spacing: 16) {
                // 火柴人动画区域（场景重现，包含叠加的场景描述卡片）
                ZStack(alignment: .topLeading) {
                    SceneReplayView(description: sceneDescription)
                    SceneDescriptionCard(description: sceneDescription)
                        .offset(x: 54.68, y: 42.43)
                }
                .frame(height: 183.61)
                
                // AI策略建议标题
                Text("AI Strategy: Bold Response")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // 策略按钮
                VStack(spacing: 8) {
                    StrategyButton(
                        type: .highEQ,
                        isSelected: selectedStrategy == .highEQ,
                        action: { selectedStrategy = .highEQ }
                    )
                    
                    StrategyButton(
                        type: .aggressive,
                        isSelected: selectedStrategy == .aggressive,
                        action: { selectedStrategy = .aggressive }
                    )
                    
                    StrategyButton(
                        type: .evasive,
                        isSelected: selectedStrategy == .evasive,
                        action: { selectedStrategy = .evasive }
                    )
                }
            }
            .padding(16)
        }
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1.38)
        )
        .cornerRadius(12)
        .shadow(color: AppColors.border, radius: 0, x: 3, y: 3)
    }
}

// 场景回放视图（火柴人动画区域）
struct SceneReplayView: View {
    let description: String
    
    var body: some View {
        // 背景（灰色）
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#D1D5DC"), lineWidth: 1.38)
            )
            .overlay(
                // 这里应该显示火柴人动画
                // 目前使用占位符
                Text("Scene Replay")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            )
    }
}

// 场景描述卡片
struct SceneDescriptionCard: View {
    let description: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("\"\(description)\"")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
            
            Text("Pass the buck! 🥫")
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .foregroundColor(AppColors.primaryText)
        }
        .padding(.horizontal, 17.37)
        .padding(.vertical, 17.37)
        .frame(width: 217.05, height: 98.74)
        .background(Color.white.opacity(0.15))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black, lineWidth: 1.38)
        )
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// 策略类型
enum StrategyType {
    case highEQ      // 高情商回复
    case aggressive  // 发疯/强势回复
    case evasive     // 装傻/打马虎眼
}

// 策略按钮
struct StrategyButton: View {
    let type: StrategyType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 图标或emoji
                if type == .evasive {
                    Text("🙈")
                        .font(.system(size: 18))
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(textColor)
                }
                
                Text(buttonText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(AppColors.border, lineWidth: 1.38)
            )
            .cornerRadius(999)
            .shadow(color: AppColors.border, radius: 0, x: 2, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        switch type {
        case .highEQ:
            return Color(hex: "#60A5FA")
        case .aggressive:
            return Color(hex: "#F87171")
        case .evasive:
            return Color(hex: "#34D399")
        }
    }
    
    private var iconName: String {
        switch type {
        case .highEQ:
            return "heart.fill"
        case .aggressive:
            return "flame.fill"
        default:
            return ""
        }
    }
    
    private var buttonText: String {
        switch type {
        case .highEQ:
            return "High-EQ Response"
        case .aggressive:
            return "Bold Response"
        case .evasive:
            return "Play Dumb"
        }
    }
}

// 策略分析数据模型
struct StrategyAnalysis: Codable {
    let sceneDescription: String
    let strategies: [StrategySuggestion]
}

struct StrategySuggestion: Codable {
    let type: String // "highEQ", "aggressive", "evasive"
    let title: String
    let content: String
    let reasoning: String
}
