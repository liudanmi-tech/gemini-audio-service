//
//  TodayMoodView.swift
//  WorkSurvivalGuide
//
//  今日心情组件 - 按照Figma设计稿实现（带圆环进度条）
//

import SwiftUI

struct TodayMoodView: View {
    let emotionScore: Int?
    let moodStats: [MoodStat]?
    
    private var score: Int {
        let s = emotionScore ?? 60
        return max(0, min(100, s))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text("心情")
                .font(AppFonts.cardTitle)
                .foregroundColor(AppColors.headerText)
            
            HStack(alignment: .center, spacing: 0) {
                // 左侧：圆环进度条 + 情绪分数
                ZStack {
                    // 背景圆环（灰色）
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 76.53, height: 76.53)
                    
                    // 进度圆环（根据分数显示颜色，clamp 避免 NaN）
                    Circle()
                        .trim(from: 0, to: min(1, max(0, CGFloat(score) / 100)))
                        .stroke(
                            scoreColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 76.53, height: 76.53)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: score)
                    
                    // 中心分数文字
                    VStack(spacing: 0) {
                        HStack(alignment: .bottom, spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.headerText)
                            
                            Text("/100")
                                .font(AppFonts.time)
                                .foregroundColor(AppColors.secondaryText)
                                .padding(.leading, 4)
                                .padding(.bottom, 4)
                        }
                    }
                }
                .frame(width: 76.53, height: 76.53)
                
                Spacer()
                
                // 右侧：情绪统计
                if let stats = moodStats, !stats.isEmpty {
                    HStack(spacing: 16) {
                        ForEach(stats.prefix(2)) { stat in
                            MoodStatView(stat: stat)
                        }
                    }
                }
            }
        }
        .padding(21.5)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1.51)
        )
        .cornerRadius(12)
        .shadow(color: AppColors.border, radius: 0, x: 3, y: 3)
    }
    
    private var scoreColor: Color {
        if score >= 70 {
            return Color(hex: "#00C950") // 绿色
        } else if score >= 40 {
            return Color(hex: "#FF6900") // 橙色
        } else {
            return Color(hex: "#C10007") // 红色
        }
    }
}

struct MoodStatView: View {
    let stat: MoodStat
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(stat.name)
                .font(AppFonts.time)
                .foregroundColor(AppColors.secondaryText)
            
            Text("\(stat.count) 次")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(stat.color)
        }
    }
}

// 情绪统计数据模型
struct MoodStat: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: Color
    
    static let example: [MoodStat] = [
        MoodStat(name: "叹气", count: 8, color: Color(hex: "#FF6900")),
        MoodStat(name: "哈哈哈", count: 12, color: Color(hex: "#00C950"))
    ]
}
