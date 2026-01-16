//
//  Task.swift
//  WorkSurvivalGuide
//
//  任务数据模型
//

import Foundation

// 任务状态枚举
enum TaskStatus: String, Codable {
    case recording = "recording"    // 录制中
    case analyzing = "analyzing"    // 分析中
    case archived = "archived"       // 已归档
    case burned = "burned"          // 已焚毁
    case failed = "failed"          // 分析失败
}

// 任务数据模型（重命名为 TaskItem 以避免与 Swift 的并发 Task 类型冲突）
struct TaskItem: Codable, Identifiable {
    let id: String                    // session_id
    let title: String                 // 任务标题
    let startTime: Date               // 开始时间
    let endTime: Date?                // 结束时间
    let duration: Int                 // 时长（秒）
    let tags: [String]                // 标签数组
    let status: TaskStatus            // 状态
    let emotionScore: Int?            // 情绪分数 (0-100)
    let speakerCount: Int?            // 说话人数
    
    // 自定义 CodingKeys 用于处理 API 返回的字段名
    enum CodingKeys: String, CodingKey {
        case id = "session_id"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case tags
        case status
        case emotionScore = "emotion_score"
        case speakerCount = "speaker_count"
    }
    
    // 便利初始化器（用于直接创建 Task，不通过 JSON 解码）
    init(
        id: String,
        title: String,
        startTime: Date,
        endTime: Date?,
        duration: Int,
        tags: [String],
        status: TaskStatus,
        emotionScore: Int? = nil,
        speakerCount: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.tags = tags
        self.status = status
        self.emotionScore = emotionScore
        self.speakerCount = speakerCount
    }
    
    // 自定义日期解码器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        
        // 解析日期字符串
        let startTimeString = try container.decode(String.self, forKey: .startTime)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        startTime = dateFormatter.date(from: startTimeString) ?? Date()
        
        // 解析可选的结束时间
        if let endTimeString = try? container.decode(String.self, forKey: .endTime) {
            endTime = dateFormatter.date(from: endTimeString)
        } else {
            endTime = nil
        }
        
        duration = try container.decode(Int.self, forKey: .duration)
        tags = try container.decode([String].self, forKey: .tags)
        status = try container.decode(TaskStatus.self, forKey: .status)
        emotionScore = try? container.decode(Int.self, forKey: .emotionScore)
        speakerCount = try? container.decode(Int.self, forKey: .speakerCount)
    }
    
    // 格式化时长显示
    var durationString: String {
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes > 0 {
            return "\(minutes)分钟"
        } else {
            return "\(seconds)秒"
        }
    }
    
    // 格式化时间范围显示
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: startTime)
        if let endTime = endTime {
            let end = formatter.string(from: endTime)
            return "\(start) - \(end)"
        }
        return start
    }
}

// MARK: - API 响应模型

// API 通用响应结构
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: String?
}

// 任务列表响应
struct TaskListResponse: Codable {
    let sessions: [TaskItem]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let page: Int
        let pageSize: Int
        let total: Int
        let totalPages: Int
        
        enum CodingKeys: String, CodingKey {
            case page
            case pageSize = "page_size"
            case total
            case totalPages = "total_pages"
        }
    }
}

// 上传响应
struct UploadResponse: Codable {
    let sessionId: String
    let audioId: String
    let title: String
    let status: String
    let estimatedDuration: Int?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case audioId = "audio_id"
        case title
        case status
        case estimatedDuration = "estimated_duration"
        case createdAt = "created_at"
    }
}

// 任务详情响应
struct TaskDetailResponse: Codable {
    let sessionId: String
    let title: String
    let startTime: Date
    let endTime: Date?
    let duration: Int
    let tags: [String]
    let status: String
    let emotionScore: Int?
    let speakerCount: Int?
    let dialogues: [DialogueItem]
    let risks: [String]
    let summary: String?  // 新增：对话总结
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case title
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case tags
        case status
        case emotionScore = "emotion_score"
        case speakerCount = "speaker_count"
        case dialogues
        case risks
        case summary  // 新增
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 自定义日期解码器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        title = try container.decode(String.self, forKey: .title)
        
        let startTimeString = try container.decode(String.self, forKey: .startTime)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        startTime = dateFormatter.date(from: startTimeString) ?? Date()
        
        if let endTimeString = try? container.decode(String.self, forKey: .endTime) {
            endTime = dateFormatter.date(from: endTimeString)
        } else {
            endTime = nil
        }
        
        duration = try container.decode(Int.self, forKey: .duration)
        tags = try container.decode([String].self, forKey: .tags)
        status = try container.decode(String.self, forKey: .status)
        emotionScore = try? container.decode(Int.self, forKey: .emotionScore)
        speakerCount = try? container.decode(Int.self, forKey: .speakerCount)
        dialogues = try container.decode([DialogueItem].self, forKey: .dialogues)
        risks = try container.decode([String].self, forKey: .risks)
        summary = try? container.decode(String.self, forKey: .summary)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
    
    // 便利初始化方法（用于创建临时详情）
    init(
        sessionId: String,
        title: String,
        startTime: Date,
        endTime: Date?,
        duration: Int,
        tags: [String],
        status: String,
        emotionScore: Int?,
        speakerCount: Int?,
        dialogues: [DialogueItem],
        risks: [String],
        summary: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.sessionId = sessionId
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.tags = tags
        self.status = status
        self.emotionScore = emotionScore
        self.speakerCount = speakerCount
        self.dialogues = dialogues
        self.risks = risks
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// 对话项（用于详情）
struct DialogueItem: Codable {
    let speaker: String
    let content: String
    let tone: String
    let timestamp: String?  // 时间戳格式："MM:SS"
    let isMe: Bool?  // 新增：是否是我说的
    
    enum CodingKeys: String, CodingKey {
        case speaker
        case content
        case tone
        case timestamp
        case isMe = "is_me"
    }
}

// 任务状态响应
struct TaskStatusResponse: Codable {
    let sessionId: String
    let status: String
    let progress: Double
    let estimatedTimeRemaining: Int
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case progress
        case estimatedTimeRemaining = "estimated_time_remaining"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        status = try container.decode(String.self, forKey: .status)
        progress = try container.decode(Double.self, forKey: .progress)
        estimatedTimeRemaining = try container.decode(Int.self, forKey: .estimatedTimeRemaining)
        
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }
    
    // 便利初始化器
    init(sessionId: String, status: String, progress: Double, estimatedTimeRemaining: Int, updatedAt: Date) {
        self.sessionId = sessionId
        self.status = status
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.updatedAt = updatedAt
    }
}

