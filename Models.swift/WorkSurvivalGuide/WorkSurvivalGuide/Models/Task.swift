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
    let summary: String?              // 对话总结（可选）
    
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
        case summary
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
        speakerCount: Int? = nil,
        summary: String? = nil
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
        self.summary = summary
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
        summary = try? container.decode(String.self, forKey: .summary)
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
    
    // 精炼summary为标题，控制在30字以内
    var refinedTitle: String {
        guard let summary = summary, !summary.isEmpty else {
            // 如果没有summary，使用原始title
            return title
        }
        
        // 移除多余的空白字符
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 如果trimmed后为空，使用原始title
        guard !trimmed.isEmpty else {
            return title
        }
        
        // 如果已经小于等于30字，直接返回
        if trimmed.count <= 30 {
            return trimmed
        }
        
        // 截取前30字
        let index = trimmed.index(trimmed.startIndex, offsetBy: 30, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
        var result = String(trimmed[..<index])
        
        // 尝试在最后一个标点符号或空格处截断，使文本更自然
        if let lastPunctuation = result.lastIndex(where: { "。！？，；：".contains($0) }) {
            let punctuationIndex = result.index(after: lastPunctuation)
            result = String(result[..<punctuationIndex])
        } else if let lastSpace = result.lastIndex(of: " ") {
            result = String(result[..<lastSpace])
        } else if let lastSpace = result.lastIndex(of: "　") {
            result = String(result[..<lastSpace])
        }
        
        // 如果截断后仍然超过30字，强制截取
        if result.count > 30 {
            let forceIndex = result.index(result.startIndex, offsetBy: 30, limitedBy: result.endIndex) ?? result.endIndex
            result = String(result[..<forceIndex])
        }
        
        // 确保返回的字符串不为空，如果为空则使用原始title
        return result.isEmpty ? title : result
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
        /// 服务端可能不返回（列表性能优化后只返回 has_more），缺省为 0
        let total: Int
        /// 服务端可能不返回，缺省为 1
        let totalPages: Int
        /// 是否有更多页（服务端优化后使用）
        let hasMore: Bool

        enum CodingKeys: String, CodingKey {
            case page
            case pageSize = "page_size"
            case total
            case totalPages = "total_pages"
            case hasMore = "has_more"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            page = try c.decode(Int.self, forKey: .page)
            pageSize = try c.decode(Int.self, forKey: .pageSize)
            total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
            totalPages = try c.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
            hasMore = try c.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        }

        init(page: Int, pageSize: Int, total: Int, totalPages: Int, hasMore: Bool = false) {
            self.page = page
            self.pageSize = pageSize
            self.total = total
            self.totalPages = totalPages
            self.hasMore = hasMore
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
    /// 分析失败时服务端返回的失败原因
    let failureReason: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case progress
        case estimatedTimeRemaining = "estimated_time_remaining"
        case updatedAt = "updated_at"
        case failureReason = "failure_reason"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        status = try container.decode(String.self, forKey: .status)
        progress = try container.decode(Double.self, forKey: .progress)
        estimatedTimeRemaining = try container.decode(Int.self, forKey: .estimatedTimeRemaining)
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }

    // 便利初始化器
    init(sessionId: String, status: String, progress: Double, estimatedTimeRemaining: Int, updatedAt: Date, failureReason: String? = nil) {
        self.sessionId = sessionId
        self.status = status
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.updatedAt = updatedAt
        self.failureReason = failureReason
    }
}

