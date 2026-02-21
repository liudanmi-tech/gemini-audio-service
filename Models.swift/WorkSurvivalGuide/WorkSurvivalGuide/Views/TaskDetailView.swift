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
    @State private var errorMessage: String?
    @State private var moodStats: [MoodStat] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景色（底层）
                AppColors.background
                    .ignoresSafeArea()
                
                // 信纸网格底纹（在背景色上方）
                PaperGridBackground()
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 23.99) { // 卡片间距改为 23.99px
                    // Header（返回按钮 + 标题）
                    DetailHeaderView()
                        .padding(.top, 10) // 进一步减少顶部间距，让内容更靠近顶部
                    
                    // 顶部日期/时间信息栏
                    DateTimeInfoBar(task: task)
                    
                    // 移除今日心情模块（Figma中没有对应设计）
                    
                    // 错误提示
                    if let errorMessage = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button(action: {
                                loadTaskDetail()
                            }) {
                                Text("重试")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                    
                    // 对话复盘模块
                    // 即使 dialogues 为空，也显示模块（可能正在加载中）
                    if let detail = detail {
                        if detail.dialogues.isEmpty {
                            // 对话内容为空（可能正在加载），显示占位符
                            VStack(alignment: .leading, spacing: 16) {
                                Text("对话复盘")
                                    .font(AppFonts.cardTitle)
                                    .foregroundColor(AppColors.headerText)
                                    .padding(.horizontal, 21.5)
                                    .padding(.top, 21.5)
                                
                                // 如果有总结，显示总结（优先 detail，无则用 task 列表的总结）
                                if let summary = (detail.summary ?? task.summary), !summary.isEmpty {
                                    Text(summary)
                                        .font(.system(size: 14, weight: .regular, design: .rounded))
                                        .foregroundColor(AppColors.headerText.opacity(0.8))
                                        .lineSpacing(4)
                                        .padding(.horizontal, 21.5)
                                        .padding(.bottom, 8)
                                }
                                
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("加载对话内容中...")
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            }
                            .background(AppColors.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.border, lineWidth: 1.51)
                            )
                            .cornerRadius(12)
                            .shadow(color: AppColors.border, radius: 0, x: 3, y: 3)
                            .padding(.bottom, 21.5)
                        } else {
                            // 有对话内容，正常显示（优先 detail.summary，无则 fallback 到 task.summary）
                            DialogueReviewView(
                                summary: detail.summary ?? task.summary,
                                dialogues: detail.dialogues
                            )
                        }
                    }
                    
                    // 回放分析与策略模块（使用新的策略分析视图，支持图片显示）
                    // 即使策略分析失败，也不影响详情显示
                    if task.status == .archived {
                        StrategyAnalysisView_Updated(
                            sessionId: task.id,
                            baseURL: NetworkManager.shared.getBaseURL()
                        )
                    }
                    }
                    .frame(width: max(0, geometry.size.width - 19.99 * 2), alignment: .leading) // 明确限制宽度，避免负值导致 NaN
                    .padding(.horizontal, 19.99) // 根据Figma: padding horizontal 19.99px（左右各19.99px）
                    .padding(.top, 0) // Header已有padding.top
                    .padding(.bottom, 20)
                }
                .contentShape(Rectangle()) // 确保可滚动区域正确
                
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(AppColors.headerText)
                            Text("加载详情中...")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(AppColors.headerText)
                        }
                        .padding(24)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // 优先使用缓存
                let cacheManager = DetailCacheManager.shared
                
                // 先检查缓存
                if let cachedDetail = cacheManager.getCachedDetail(sessionId: task.id) {
                    print("✅ [TaskDetailView] 使用缓存的详情数据: \(task.id)")
                    self.detail = cachedDetail
                    self.isLoading = false
                    self.errorMessage = nil
                    generateMoodStats()
                    return
                }
                
                // 如果任务已完成，立即显示基本信息，然后后台加载完整详情
                if task.status == .archived {
                    // 先使用任务基本信息创建临时详情，让用户立即看到内容
                    Task { @MainActor in
                        if self.detail == nil {
                            // 创建临时详情对象，使用任务基本信息
                            self.createTemporaryDetail()
                        }
                        // 后台加载完整详情（不显示加载提示，因为已有临时详情）
                        self.loadTaskDetail(silent: true)
                    }
                } else {
                    // 如果已有详情，生成情绪统计数据
                    generateMoodStats()
                }
            }
        }
    }
    
    private func createTemporaryDetail() {
        // #region agent log
        let logData: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "C",
            "location": "TaskDetailView.swift:119",
            "message": "createTemporaryDetail called",
            "data": [
                "taskId": task.id,
                "hasEmotionScore": task.emotionScore != nil,
                "emotionScore": task.emotionScore ?? -1
            ],
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: logData),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: "/Users/liudan/Desktop/AI军师/gemini-audio-service/.cursor/debug.log") {
                fileHandle.seekToEndOfFile()
                fileHandle.write("\n".data(using: .utf8)!)
                fileHandle.write(jsonString.data(using: .utf8)!)
                fileHandle.closeFile()
            }
        }
        // #endregion
        
        // 使用任务基本信息创建临时详情，让用户立即看到内容
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let tempDetail = TaskDetailResponse(
            sessionId: task.id,
            title: task.title,
            startTime: task.startTime,
            endTime: task.endTime,
            duration: task.duration,
            tags: task.tags,
            status: task.status.rawValue,
            emotionScore: task.emotionScore,
            speakerCount: task.speakerCount,
            dialogues: [], // 暂时为空，等待完整数据加载
            risks: [],
            summary: task.summary, // 使用列表接口返回的总结，确保即时显示
            createdAt: dateFormatter.string(from: task.startTime),
            updatedAt: dateFormatter.string(from: task.endTime ?? task.startTime)
        )
        self.detail = tempDetail
        // 确保不显示加载提示（因为已有临时详情）
        self.isLoading = false
        
        // #region agent log
        let logData2: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "C",
            "location": "TaskDetailView.swift:141",
            "message": "Temporary detail created and assigned",
            "data": [
                "detailIsNil": detail == nil,
                "isLoading": isLoading,
                "isLoadingSetToFalse": true
            ],
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: logData2),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: "/Users/liudan/Desktop/AI军师/gemini-audio-service/.cursor/debug.log") {
                fileHandle.seekToEndOfFile()
                fileHandle.write("\n".data(using: .utf8)!)
                fileHandle.write(jsonString.data(using: .utf8)!)
                fileHandle.closeFile()
            }
        }
        // #endregion
        
        generateMoodStats()
    }
    
    private func loadTaskDetail(silent: Bool = false) {
        let cacheManager = DetailCacheManager.shared
        
        // 先检查缓存
        if let cachedDetail = cacheManager.getCachedDetail(sessionId: task.id) {
            print("✅ [TaskDetailView] 使用缓存的详情数据: \(task.id)")
            Task { @MainActor in
                self.detail = cachedDetail
                self.isLoading = false
                self.errorMessage = nil
                generateMoodStats()
            }
            return
        }
        
        // 如果已经有完整详情，不重复加载
        if let existingDetail = detail, !existingDetail.dialogues.isEmpty {
            return
        }
        
        // 如果正在加载中，跳过重复请求
        if cacheManager.isLoadingDetail(for: task.id) {
            print("⚠️ [TaskDetailView] 详情正在加载中，跳过重复请求")
            return
        }
        
        // 只在没有详情且不是静默模式时显示加载提示
        // 如果已有临时详情（silent=true），不显示加载提示
        if !silent && detail == nil {
            isLoading = true
        }
        errorMessage = nil
        
        // 设置加载状态
        cacheManager.setLoadingDetail(true, for: task.id)
        
        Task {
            defer {
                // 清除加载状态
                cacheManager.setLoadingDetail(false, for: task.id)
            }
            
            do {
                print("📋 [TaskDetailView] 开始加载任务详情，sessionId: \(task.id)")
                let taskDetail = try await NetworkManager.shared.getTaskDetail(sessionId: task.id)
                print("✅ [TaskDetailView] 任务详情加载成功")
                
                // 缓存详情
                cacheManager.cacheDetail(taskDetail, for: task.id)
                
                await MainActor.run {
                    self.detail = taskDetail
                    self.isLoading = false
                    self.errorMessage = nil
                    generateMoodStats()
                }
            } catch {
                print("❌ [TaskDetailView] 加载详情失败: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("  错误域: \(nsError.domain)")
                    print("  错误码: \(nsError.code)")
                    print("  用户信息: \(nsError.userInfo)")
                }
                
                await MainActor.run {
                    self.isLoading = false
                    // 生成友好的错误提示
                    if let nsError = error as NSError? {
                        if nsError.code == -1001 || nsError.localizedDescription.contains("timeout") {
                            self.errorMessage = "请求超时，请检查网络连接后重试"
                        } else if nsError.code == 404 {
                            self.errorMessage = "任务不存在或已被删除"
                        } else if nsError.code == 401 || nsError.code == 403 {
                            self.errorMessage = "认证失败，请重新登录"
                        } else {
                            self.errorMessage = "加载失败: \(error.localizedDescription)"
                        }
                    } else {
                        self.errorMessage = "加载失败: \(error.localizedDescription)"
                    }
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
                        .frame(width: 39.98, height: 39.98)
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.headerText)
                }
            }
            
            Spacer()
            
            Text("详情")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(AppColors.headerText)
                .tracking(0.5) // letterSpacing 2.5% of 20px = 0.5pt
            
            Spacer()
            
            // 占位，保持居中
            Color.clear
                .frame(width: 39.98, height: 39.98)
        }
        .padding(.horizontal, 15.99)
        .padding(.vertical, 0)
    }
}

// 顶部日期/时间信息栏
struct DateTimeInfoBar: View {
    let task: TaskItem
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左侧：时间组件（自适应宽度，不固定）
            HStack(alignment: .center, spacing: 7.996843338012695) { // 根据Figma: gap 7.99px
                // 日历图标
                Image(systemName: "calendar")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.headerText.opacity(0.8))
                    .frame(width: 18, height: 18)
                
                // 日期文本（格式：2026/01/20 星期一）
                Text(dateTimeString)
                    .font(.system(size: 14, weight: .bold, design: .rounded)) // Nunito 700, 14px
                    .foregroundColor(AppColors.headerText.opacity(0.8)) // rgba(94, 75, 53, 0.8)
                    .tracking(0.35) // letterSpacing 2.5% of 14px = 0.35pt
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false) // 自适应宽度
            }
            .padding(.leading, 15.99) // 根据Figma: padding left 15.99px
            .padding(.trailing, 8) // 添加右侧padding
            .frame(height: 37.37) // 根据Figma: height 37.37px，宽度自适应
            .background(
                RoundedRectangle(cornerRadius: 23144300) // 根据Figma: borderRadius: 23144300px (极大值，实际为胶囊形状)
                    .fill(Color.white.opacity(0.3)) // rgba(255, 255, 255, 0.3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 23144300)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.69) // rgba(255, 255, 255, 0.2), strokeWeight 0.69px
                    )
            )
            
            Spacer(minLength: 8) // 最小间距，确保左右元素不贴得太近
            
            // 右侧：表情图标（播放按钮，圆形，白色半透明背景）
            Button(action: {
                // TODO: 实现播放功能
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.8)) // rgba(255, 255, 255, 0.8)
                        .frame(width: 49.37, height: 49.37) // 根据Figma: 49.37 x 49.37px
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.4), lineWidth: 0.69) // rgba(255, 255, 255, 0.4), strokeWeight 0.69px
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1) // 根据Figma: boxShadow
                    
                    // 使用表情图标或播放图标
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.headerText.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading) // 确保不超出父容器
    }
    
    private var dateTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy/MM/dd EEEE"
        return formatter.string(from: task.startTime)
    }
}
