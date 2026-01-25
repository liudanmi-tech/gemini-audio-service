//
//  TaskListViewModel.swift
//  WorkSurvivalGuide
//
//  任务列表 ViewModel
//

import Foundation
import Combine

class TaskListViewModel: ObservableObject {
    static let shared = TaskListViewModel()
    
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    private var hasLoaded = false // 记录是否已经加载过数据
    private var loadingTask: Task<Void, Never>? // 当前加载任务，用于取消重复请求
    
    private init() {
        // 私有初始化器，确保单例模式
    }
    
    // 加载任务列表
    func loadTasks(date: Date? = nil, forceRefresh: Bool = false) {
        // 如果已经有数据且不在加载中，且不是强制刷新，则跳过
        if !forceRefresh && !tasks.isEmpty && !isLoading && hasLoaded {
            print("✅ [TaskListViewModel] 数据已存在，跳过加载")
            return
        }
        
        // 如果正在加载中，取消之前的任务
        if isLoading {
            print("⚠️ [TaskListViewModel] 正在加载中，跳过重复请求")
            loadingTask?.cancel()
        }
        
        isLoading = true
        errorMessage = nil
        
        loadingTask = Task {
            let loadStartTime = Date()
            print("⏱️ [TaskListViewModel] ========== 开始加载任务列表 ==========")
            print("⏱️ [TaskListViewModel] 开始时间: \(loadStartTime)")
            
            do {
                let response = try await self.networkManager.getTaskList(date: date)
                let networkTime = Date().timeIntervalSince(loadStartTime)
                print("⏱️ [TaskListViewModel] 网络请求完成，耗时: \(String(format: "%.3f", networkTime))秒")
                
                // 检查任务是否被取消
                guard !Task.isCancelled else {
                    print("⚠️ [TaskListViewModel] 加载任务已取消")
                    return
                }
                
                let mergeStartTime = Date()
                await MainActor.run {
                    // 合并任务列表，保留已有任务的 summary 字段（如果 API 返回的任务没有 summary）
                    self.tasks = self.mergeTasks(apiTasks: response.sessions)
                    let mergeTime = Date().timeIntervalSince(mergeStartTime)
                    print("⏱️ [TaskListViewModel] 数据合并完成，耗时: \(String(format: "%.3f", mergeTime))秒")
                    
                    self.isLoading = false
                    self.hasLoaded = true
                    
                    let totalTime = Date().timeIntervalSince(loadStartTime)
                    print("⏱️ [TaskListViewModel] ========== 任务列表加载完成 ==========")
                    print("⏱️ [TaskListViewModel] 总耗时: \(String(format: "%.3f", totalTime))秒")
                    print("⏱️ [TaskListViewModel] 任务数量: \(self.tasks.count)")
                    
                    // 对于archived状态且没有summary的任务，异步获取详情补充summary（不阻塞主流程）
                    // 延迟执行，避免影响首次加载速度
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 延迟0.5秒
                        self.loadMissingSummaries()
                    }
                }
            } catch {
                // 检查任务是否被取消
                guard !Task.isCancelled else {
                    print("⚠️ [TaskListViewModel] 加载任务已取消")
                    return
                }
                
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("加载任务失败: \(error)")
                }
            }
        }
    }
    
    // 刷新任务列表（强制刷新）
    func refreshTasks() {
        loadTasks(forceRefresh: true)
    }
    
    // 异步刷新任务列表（用于 refreshable）
    func refreshTasksAsync() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let response = try await networkManager.getTaskList(date: nil)
            await MainActor.run {
                // 合并任务列表，保留已有任务的 summary 字段（如果 API 返回的任务没有 summary）
                self.tasks = self.mergeTasks(apiTasks: response.sessions)
                self.isLoading = false
                
                // 对于archived状态且没有summary的任务，异步获取详情补充summary
                self.loadMissingSummaries()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                print("刷新任务失败: \(error)")
            }
        }
    }
    
    // 添加新任务（用于录制后创建）
    func addNewTask(_ task: TaskItem) {
        print("📝 [TaskListViewModel] ========== 添加新任务 ==========")
        print("📝 [TaskListViewModel] 任务ID: \(task.id)")
        print("📝 [TaskListViewModel] 任务标题: \(task.title)")
        print("📝 [TaskListViewModel] 任务状态: \(task.status)")
        print("📝 [TaskListViewModel] 当前任务数量: \(tasks.count)")
        
        tasks.insert(task, at: 0) // 添加到列表顶部
        
        print("✅ [TaskListViewModel] 任务已添加，当前任务数量: \(tasks.count)")
    }
    
    // 更新任务（用于分析完成后更新）
    func updateTask(_ updatedTask: TaskItem) {
        print("🔄 [TaskListViewModel] ========== 更新任务 ==========")
        print("🔄 [TaskListViewModel] 任务ID: \(updatedTask.id)")
        print("🔄 [TaskListViewModel] 任务标题: \(updatedTask.title)")
        print("🔄 [TaskListViewModel] 任务状态: \(updatedTask.status)")
        
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            print("✅ [TaskListViewModel] 找到任务，索引: \(index)")
            tasks[index] = updatedTask
            print("✅ [TaskListViewModel] 任务已更新")
        } else {
            print("⚠️ [TaskListViewModel] 未找到要更新的任务")
        }
    }
    
    // 更新任务状态（用于录音停止后更新状态）
    func updateTaskStatus(_ updatedTask: TaskItem) {
        print("🔄 [TaskListViewModel] ========== 更新任务状态 ==========")
        print("🔄 [TaskListViewModel] 任务ID: \(updatedTask.id)")
        print("🔄 [TaskListViewModel] 任务状态: \(updatedTask.status)")
        
        if let index = tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            print("✅ [TaskListViewModel] 找到任务，索引: \(index)")
            tasks[index] = updatedTask
            print("✅ [TaskListViewModel] 任务状态已更新")
        } else {
            print("⚠️ [TaskListViewModel] 未找到要更新的任务")
        }
    }
    
    // 删除任务（用于替换本地创建的卡片）
    func deleteTask(taskId: String) {
        print("🗑️ [TaskListViewModel] ========== 删除任务 ==========")
        print("🗑️ [TaskListViewModel] 任务ID: \(taskId)")
        print("🗑️ [TaskListViewModel] 当前任务数量: \(tasks.count)")
        
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            print("✅ [TaskListViewModel] 找到任务，索引: \(index)")
            tasks.remove(at: index)
            print("✅ [TaskListViewModel] 任务已删除，当前任务数量: \(tasks.count)")
        } else {
            print("⚠️ [TaskListViewModel] 未找到要删除的任务")
        }
    }
    
    // 按天分组任务
    var groupedTasks: [String: [TaskItem]] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Dictionary(grouping: tasks) { (task: TaskItem) -> String in
            formatter.string(from: task.startTime)
        }
    }
    
    // 获取分组标题
    func groupTitle(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInYesterday(date) {
            return "昨天"
        } else {
            formatter.dateFormat = "yyyy年MM月dd日"
            return formatter.string(from: date)
        }
    }
    
    // 合并任务列表，保留已有任务的 summary 字段
    private func mergeTasks(apiTasks: [TaskItem]) -> [TaskItem] {
        // 创建已有任务的 summary 映射表（以 task.id 为 key）
        let existingSummaries = Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            task.summary != nil ? (task.id, task.summary) : nil
        })
        
        // 更新 API 返回的任务，如果 API 任务没有 summary 但本地有，则保留本地的 summary
        return apiTasks.map { apiTask in
            if apiTask.summary == nil || apiTask.summary?.isEmpty == true,
               let existingSummary = existingSummaries[apiTask.id] {
                // API 任务没有 summary，但本地有，创建新任务保留 summary
                return TaskItem(
                    id: apiTask.id,
                    title: apiTask.title,
                    startTime: apiTask.startTime,
                    endTime: apiTask.endTime,
                    duration: apiTask.duration,
                    tags: apiTask.tags,
                    status: apiTask.status,
                    emotionScore: apiTask.emotionScore,
                    speakerCount: apiTask.speakerCount,
                    summary: existingSummary
                )
            } else {
                // API 任务有 summary 或本地也没有，直接使用 API 任务
                return apiTask
            }
        }
    }
    
    // 为archived状态且没有summary的任务异步加载summary
    private func loadMissingSummaries() {
        // 找出所有archived状态且没有summary的任务
        let tasksNeedingSummary = tasks.filter { task in
            task.status == .archived && (task.summary == nil || task.summary?.isEmpty == true)
        }
        
        guard !tasksNeedingSummary.isEmpty else {
            return
        }
        
        print("🔄 [TaskListViewModel] 发现 \(tasksNeedingSummary.count) 个任务需要补充summary，开始异步加载...")
        
        // 使用 TaskGroup 控制并发数量，避免同时发起过多请求
        Task {
            // 限制并发数量为5，避免过多并发请求
            let maxConcurrent = 5
            let chunks = tasksNeedingSummary.chunked(into: maxConcurrent)
            
            for chunk in chunks {
                await withTaskGroup(of: Void.self) { group in
                    for task in chunk {
                        group.addTask {
                            do {
                                let detail = try await self.networkManager.getTaskDetail(sessionId: task.id)
                                
                                // 缓存详情数据，供详情页使用
                                DetailCacheManager.shared.cacheDetail(detail, for: task.id)
                                
                                // 更新任务的summary
                                await MainActor.run {
                                    if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                                        let updatedTask = TaskItem(
                                            id: task.id,
                                            title: task.title,
                                            startTime: task.startTime,
                                            endTime: task.endTime,
                                            duration: task.duration,
                                            tags: task.tags,
                                            status: task.status,
                                            emotionScore: task.emotionScore,
                                            speakerCount: task.speakerCount,
                                            summary: detail.summary
                                        )
                                        self.tasks[index] = updatedTask
                                        print("✅ [TaskListViewModel] 已为任务 \(task.id) 补充summary并缓存详情")
                                    }
                                }
                            } catch {
                                print("⚠️ [TaskListViewModel] 获取任务 \(task.id) 的summary失败: \(error)")
                            }
                        }
                    }
                }
            }
            print("✅ [TaskListViewModel] 所有summary加载完成")
        }
    }
}

// 辅助扩展：将数组分块（文件级别）
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

