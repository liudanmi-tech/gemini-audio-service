//
//  TaskListViewModel.swift
//  WorkSurvivalGuide
//
//  任务列表 ViewModel
//

import Foundation
import Combine

class TaskListViewModel: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let networkManager = NetworkManager.shared
    
    // 加载任务列表
    func loadTasks(date: Date? = nil) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await networkManager.getTaskList(date: date)
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
    
    // 按天分组任务
    var groupedTasks: [String: [Task]] {
        Dictionary(grouping: tasks) { task in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: task.startTime)
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

