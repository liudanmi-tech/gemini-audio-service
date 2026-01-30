//
//  MockNetworkService.swift
//  WorkSurvivalGuide
//
//  Mock 数据服务（用于测试）
//

import Foundation

class MockNetworkService {
    static let shared = MockNetworkService()
    
    private init() {}
    
    // 模拟网络延迟
    private func delay(seconds: Double = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
    
    // Mock 获取任务列表
    func getTaskList(
        date: Date? = nil,
        status: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> TaskListResponse {
        // 模拟网络延迟
        await delay(seconds: 0.5)
        
        // 生成 Mock 数据
        let mockTasks = generateMockTasks()
        
        return TaskListResponse(
            sessions: mockTasks,
            pagination: TaskListResponse.Pagination(
                page: page,
                pageSize: pageSize,
                total: mockTasks.count,
                totalPages: 1,
                hasMore: false
            )
        )
    }
    
    // Mock 上传音频文件
    func uploadAudio(
        fileURL: URL,
        sessionId: String? = nil
    ) async throws -> UploadResponse {
        // 模拟上传延迟
        await delay(seconds: 2.0)
        
        // 生成 Mock 响应
        let newSessionId = sessionId ?? UUID().uuidString
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        let timeString = formatter.string(from: Date())
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        return UploadResponse(
            sessionId: newSessionId,
            audioId: UUID().uuidString,
            title: "录音 \(timeString)",
            status: "analyzing",
            estimatedDuration: 300,
            createdAt: dateFormatter.string(from: Date())
        )
    }
    
    // 生成 Mock 任务数据
    private func generateMockTasks() -> [TaskItem] {
        let calendar = Calendar.current
        let now = Date()
        let formatter = ISO8601DateFormatter()
        
        var tasks: [TaskItem] = []
        
        // 今天的任务
        if let task1 = createMockTask(
            sessionId: "mock-task-1",
            title: "Q1预算撕逼会",
            startTime: calendar.date(byAdding: .hour, value: -2, to: now)!,
            endTime: calendar.date(byAdding: .hour, value: -1, to: now)!,
            duration: 3600,
            tags: ["#PUA预警", "#急躁", "#画饼"],
            status: "archived",
            emotionScore: 60,
            speakerCount: 3
        ) {
            tasks.append(task1)
        }
        
        if let task2 = createMockTask(
            sessionId: "mock-task-2",
            title: "晨间站会",
            startTime: calendar.date(byAdding: .hour, value: -5, to: now)!,
            endTime: calendar.date(byAdding: .hour, value: -4, to: now)!,
            duration: 3600,
            tags: ["#正常", "#进度汇报"],
            status: "archived",
            emotionScore: 75,
            speakerCount: 5
        ) {
            tasks.append(task2)
        }
        
        if let task3 = createMockTask(
            sessionId: "mock-task-3",
            title: "产品需求评审",
            startTime: calendar.date(byAdding: .hour, value: -8, to: now)!,
            endTime: calendar.date(byAdding: .hour, value: -7, to: now)!,
            duration: 3600,
            tags: ["#争论", "#需求变更"],
            status: "analyzing",
            emotionScore: nil,
            speakerCount: nil
        ) {
            tasks.append(task3)
        }
        
        // 昨天的任务
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           let task4 = createMockTask(
            sessionId: "mock-task-4",
            title: "周会",
            startTime: yesterday,
            endTime: yesterday.addingTimeInterval(3600),
            duration: 3600,
            tags: ["#周报", "#计划"],
            status: "archived",
            emotionScore: 80,
            speakerCount: 8
        ) {
            tasks.append(task4)
        }
        
        // 前天的任务
        if let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: now),
           let task5 = createMockTask(
            sessionId: "mock-task-5",
            title: "技术方案讨论",
            startTime: dayBeforeYesterday,
            endTime: dayBeforeYesterday.addingTimeInterval(7200),
            duration: 7200,
            tags: ["#技术", "#方案"],
            status: "archived",
            emotionScore: 85,
            speakerCount: 4
        ) {
            tasks.append(task5)
        }
        
        return tasks
    }
    
    // 创建 Mock 任务（直接使用便利初始化器）
    private func createMockTask(
        sessionId: String,
        title: String,
        startTime: Date,
        endTime: Date,
        duration: Int,
        tags: [String],
        status: String,
        emotionScore: Int?,
        speakerCount: Int?
    ) -> TaskItem? {
        // 将字符串状态转换为 TaskStatus 枚举
        guard let taskStatus = TaskStatus(rawValue: status) else {
            return nil
        }
        
        // 直接使用便利初始化器创建 TaskItem
        return TaskItem(
            id: sessionId,
            title: title,
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            tags: tags,
            status: taskStatus,
            emotionScore: emotionScore,
            speakerCount: speakerCount
        )
    }
}

