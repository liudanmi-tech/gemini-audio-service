//
//  EmotionTrendChartView.swift
//  WorkSurvivalGuide
//
//  跨对话心情趋势折线图 - 使用 Swift Charts
//

import SwiftUI
import Charts

struct EmotionTrendChartView: View {
    let points: [EmotionTrendPoint]
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private static let moodOrder = ["高兴", "亢奋", "平常心", "焦虑", "悲伤"]
    
    private var moodScore: (String) -> Double {
        { mood in
            guard let idx = Self.moodOrder.firstIndex(of: mood) else { return 2 }
            return Double(idx)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("心情趋势")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.headerText.opacity(0.8))
            
            if points.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.headerText.opacity(0.4))
                        Text("暂无心情数据")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(AppColors.cardBackground)
                .cornerRadius(12)
            } else {
                Chart {
                    ForEach(Array(points.reversed().enumerated()), id: \.element.id) { index, pt in
                        let score = moodScore(pt.moodState)
                        LineMark(
                            x: .value("序号", index),
                            y: .value("心情", score)
                        )
                        .foregroundStyle(Color(hex: "#5E7C8B"))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("序号", index),
                            y: .value("心情", score)
                        )
                        .foregroundStyle(Color(hex: "#5E7C8B"))
                        .annotation(position: .top) {
                            Text(pt.moodEmoji)
                                .font(.system(size: 14))
                        }
                    }
                }
                .chartYScale(domain: -0.5...4.5)
                .chartYAxis {
                    AxisMarks(values: [0, 1, 2, 3, 4]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self), v >= 0, v < 5 {
                                Text(Self.moodOrder[Int(v)])
                                    .font(.system(size: 10, design: .rounded))
                            }
                        }
                    }
                }
                .frame(height: 160)
                .padding(16)
                .background(AppColors.cardBackground)
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    EmotionTrendChartView(points: [
        EmotionTrendPoint(sessionId: "1", createdAt: "2025-01-28T10:00:00", moodState: "高兴", moodEmoji: "😊", sighCount: 0, hahaCount: 5, charCount: 200),
        EmotionTrendPoint(sessionId: "2", createdAt: "2025-01-29T09:00:00", moodState: "平常心", moodEmoji: "😐", sighCount: 2, hahaCount: 1, charCount: 150),
        EmotionTrendPoint(sessionId: "3", createdAt: "2025-01-29T14:00:00", moodState: "焦虑", moodEmoji: "😰", sighCount: 5, hahaCount: 0, charCount: 300)
    ])
}
