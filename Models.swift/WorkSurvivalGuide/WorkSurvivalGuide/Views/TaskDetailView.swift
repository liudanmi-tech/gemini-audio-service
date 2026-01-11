//
//  TaskDetailView.swift
//  WorkSurvivalGuide
//
//  任务详情视图 - 按照Figma设计稿实现
//

import SwiftUI

struct TaskDetailView: View {
    let task: TaskItem
    @State private var detail: TaskDetailResponse?
    @State private var isLoading = false
    @State private var moodStats: [MoodStat] = []
    
    var body: some View {
        ZStack {
            // 背景色
            AppColors.background
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Header（返回按钮 + 标题）
                    DetailHeaderView()
                    
                    // 今日心情模块
                    TodayMoodView(
                        emotionScore: task.emotionScore ?? detail?.emotionScore,
                        moodStats: moodStats.isEmpty ? nil : moodStats
                    )
                    
                    // 对话复盘模块
                    if let detail = detail, !detail.dialogues.isEmpty {
                        DialogueReviewView(dialogues: detail.dialogues)
                    }
                    
                    // 回放分析与策略模块
                    if let detail = detail {
                        AnalysisStrategyView(
                            sceneDescription: generateSceneDescription(from: detail),
                            strategyAnalysis: nil // TODO: 从API获取策略分析
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 88)
                .padding(.bottom, 20)
            }
            
            if isLoading {
                ProgressView("加载详情中...")
                    .tint(AppColors.headerText)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if task.status == .archived && detail == nil {
                loadTaskDetail()
            } else {
                // 如果已有详情，生成情绪统计数据
                generateMoodStats()
            }
        }
    }
    
    private func loadTaskDetail() {
        isLoading = true
        
        Task {
            do {
                let taskDetail = try await NetworkManager.shared.getTaskDetail(sessionId: task.id)
                await MainActor.run {
                    self.detail = taskDetail
                    self.isLoading = false
                    generateMoodStats()
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    print("加载详情失败: \(error)")
                }
            }
        }
    }
    
    private func generateMoodStats() {
        // 从对话中分析情绪统计
        // 这里可以根据对话的语气（tone）来统计
        guard let detail = detail else {
            // 如果没有详情，使用默认值
            moodStats = MoodStat.example
            return
        }
        
        var stats: [String: Int] = [:]
        for dialogue in detail.dialogues {
            let tone = dialogue.tone
            stats[tone, default: 0] += 1
        }
        
        moodStats = stats.map { key, value in
            MoodStat(
                name: key,
                count: value,
                color: getMoodColor(for: key)
            )
        }.sorted { $0.count > $1.count }
        
        // 如果没有统计数据，使用默认值
        if moodStats.isEmpty {
            moodStats = MoodStat.example
        }
    }
    
    private func getMoodColor(for tone: String) -> Color {
        // 根据语气返回颜色
        switch tone.lowercased() {
        case "叹气", "sigh", "无奈":
            return Color(hex: "#FF6900")
        case "哈哈哈", "laugh", "轻松", "轻松":
            return Color(hex: "#00C950")
        case "焦虑", "anxious":
            return Color(hex: "#FF6B6B")
        default:
            return AppColors.secondaryText
        }
    }
    
    private func generateSceneDescription(from detail: TaskDetailResponse) -> String {
        // 根据对话生成场景描述
        if let firstDialogue = detail.dialogues.first {
            return firstDialogue.content
        }
        return "当老板说 '周末前完成'..."
    }
}

// Detail Header视图
struct DetailHeaderView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.headerText)
                }
            }
            
            Spacer()
            
            Text("每日总结")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.headerText)
            
            Spacer()
            
            // 占位，保持居中
            Color.clear
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
    }
}
