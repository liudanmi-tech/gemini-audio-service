//
//  TodayMoodView.swift
//  WorkSurvivalGuide
//
//  今日心情组件 - 按照Figma设计稿实现
//

import SwiftUI

struct TodayMoodView: View {
    let emotionScore: Int?
    let moodStats: [MoodStat]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            Text("今日心情")
                .font(AppFonts.cardTitle)
                .foregroundColor(AppColors.headerText)
            
            HStack(alignment: .center, spacing: 0) {
                // 左侧：情绪分数
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 0) {
                        Text("\(emotionScore ?? 60)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.headerText)
                        
                        Text("/100")
                            .font(AppFonts.time)
                            .foregroundColor(AppColors.secondaryText)
                            .padding(.leading, 4)
                            .padding(.bottom, 4)
                    }
                }
                
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
        .padding(21.37)
        .background(AppColors.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.border, lineWidth: 1.38)
        )
        .cornerRadius(12)
        .shadow(color: AppColors.border, radius: 0, x: 3, y: 3)
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
