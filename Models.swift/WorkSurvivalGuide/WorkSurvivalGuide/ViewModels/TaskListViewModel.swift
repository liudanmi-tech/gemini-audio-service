//
//  TaskListViewModel.swift
//  WorkSurvivalGuide
//
//  任务列表 ViewModel
//

import Foundation
import Combine

class TaskListViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    
    // 加载任务列表
    func loadTasks(date: Date? = nil) {
        isLoading = true
        errorMessage = nil
        
        // 现在可以使用 Swift 的并发 Task 了，因为我们已经重命名了我们的 Task 结构体
        Task {
            do {
                let response = try await self.networkManager.getTaskList(date: date)
                await MainActor.run {
                    self.tasks = response.sessions
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("加载任务失败: \(error)")
                }
            }
        }
    }
    
    // 刷新任务列表
    func refreshTasks() {
        loadTasks()
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
}

