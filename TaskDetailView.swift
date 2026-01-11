//
//  TaskDetailView.swift
//  WorkSurvivalGuide
//
//  任务详情视图（简化版）
//

import SwiftUI

struct TaskDetailView: View {
    let taskId: String
    @State private var task: Task?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("加载中...")
                    .padding()
            } else if let task = task {
                VStack(alignment: .leading, spacing: 20) {
                    // 任务信息
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(task.timeRangeString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let score = task.emotionScore {
                            Text("情绪分数: \(score)分")
                                .font(.headline)
                                .foregroundColor(emotionColor(for: score))
                        }
                    }
                    .padding()
                    
                    // 标签
                    if !task.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(task.tags, id: \.self) { tag in
                                    TagView(text: tag)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    Text("详情功能开发中...")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
        }
        .navigationTitle("任务详情")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadTaskDetail()
        }
    }
    
    private func loadTaskDetail() {
        // TODO: 实现加载任务详情的逻辑
        // 暂时从列表中查找任务
        isLoading = false
    }
    
    private func emotionColor(for score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

