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
    let summary: String?             // 对话总结（可选）
    let cardTitle: String?           // 对话核心主题短标题（≤30字，可选）
    let coverImageUrl: String?        // 策略分析首图 URL（可选）
    /// 分析进度文案（仅本地展示，列表 API 不返回；如「上传中」「转写音频…」「匹配了 2 个技能」）
    let progressDescription: String?
    
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
        case cardTitle = "card_title"
        case coverImageUrl = "cover_image_url"
        case progressDescription = "progress_description"
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
        summary: String? = nil,
        cardTitle: String? = nil,
        coverImageUrl: String? = nil,
        progressDescription: String? = nil
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
        self.cardTitle = cardTitle
        self.coverImageUrl = coverImageUrl
        self.progressDescription = progressDescription
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
        cardTitle = try? container.decode(String.self, forKey: .cardTitle)
        coverImageUrl = try? container.decode(String.self, forKey: .coverImageUrl)
        progressDescription = try? container.decodeIfPresent(String.self, forKey: .progressDescription) ?? nil
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
            return title
        }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return title }
        if trimmed.count <= 30 { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 30, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
        var result = String(trimmed[..<index])
        if let lastPunctuation = result.lastIndex(where: { "。！？，；：".contains($0) }) {
            let punctuationIndex = result.index(after: lastPunctuation)
            result = String(result[..<punctuationIndex])
        } else if let lastSpace = result.lastIndex(of: " ") {
            result = String(result[..<lastSpace])
        } else if let lastSpace = result.lastIndex(of: "　") {
            result = String(result[..<lastSpace])
        }
        if result.count > 30 {
            let forceIndex = result.index(result.startIndex, offsetBy: 30, limitedBy: result.endIndex) ?? result.endIndex
            result = String(result[..<forceIndex])
        }
        return result.isEmpty ? title : result
    }
    
    /// 卡片蒙层显示的总结，控制在 3 行以内（约 75 字）
    var overlaySummary: String {
        guard let summary = summary, !summary.isEmpty else {
            return title
        }
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return title }
        if trimmed.count <= 75 { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: 75, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
        var result = String(trimmed[..<index])
        if let lastPunctuation = result.lastIndex(where: { "。！？，；：".contains($0) }) {
            let punctuationIndex = result.index(after: lastPunctuation)
            result = String(result[..<punctuationIndex])
        } else if let lastSpace = result.lastIndex(of: " ") {
            result = String(result[..<lastSpace])
        } else if let lastSpace = result.lastIndex(of: "　") {
            result = String(result[..<lastSpace])
        }
        if result.count > 75 {
            let forceIndex = result.index(result.startIndex, offsetBy: 75, limitedBy: result.endIndex) ?? result.endIndex
            result = String(result[..<forceIndex])
        }
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

// MARK: - 重大事件模型

struct MajorEvent: Codable, Identifiable {
    var id: String { sessionId }
    let sessionId: String
    let title: String
    let summary: String
    let createdAt: Date?
    let skillName: String?
    let confidenceScore: Double?
    let emotionScore: Int?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case sessionId       = "session_id"
        case title
        case summary
        case createdAt       = "created_at"
        case skillName       = "skill_name"
        case confidenceScore = "confidence_score"
        case emotionScore    = "emotion_score"
        case category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sessionId       = try c.decode(String.self, forKey: .sessionId)
        title           = (try? c.decode(String.self, forKey: .title)) ?? "对话记录"
        summary         = (try? c.decode(String.self, forKey: .summary)) ?? ""
        skillName       = try? c.decode(String.self, forKey: .skillName)
        confidenceScore = try? c.decode(Double.self, forKey: .confidenceScore)
        emotionScore    = try? c.decode(Int.self,    forKey: .emotionScore)
        category        = try? c.decode(String.self, forKey: .category)

        // Parse ISO8601 date string with and without fractional seconds
        if let dateStr = try? c.decode(String.self, forKey: .createdAt) {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = fmt.date(from: dateStr) {
                createdAt = d
            } else {
                fmt.formatOptions = [.withInternetDateTime]
                createdAt = fmt.date(from: dateStr)
            }
        } else {
            createdAt = nil
        }
    }

    /// Create a minimal TaskItem for navigation to TaskDetailView
    func toTaskItem() -> TaskItem {
        TaskItem(
            id: sessionId,
            title: title,
            startTime: createdAt ?? Date(),
            endTime: nil,
            duration: 0,
            tags: [],
            status: .archived,
            emotionScore: emotionScore
        )
    }
}

struct MajorEventsResponse: Codable {
    let events: [MajorEvent]
    let total: Int
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
    let summary: String?
    let cardTitle: String?   // Moments 封面底部短标题（≤30字）
    let coverImageUrl: String?
    let audioUrl: String?  // 原始录音播放 URL
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
        case summary
        case cardTitle = "card_title"
        case coverImageUrl = "cover_image_url"
        case audioUrl = "audio_url"
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
        cardTitle = try? container.decode(String.self, forKey: .cardTitle)
        coverImageUrl = try? container.decode(String.self, forKey: .coverImageUrl)
        audioUrl = try? container.decode(String.self, forKey: .audioUrl)
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
        cardTitle: String? = nil,
        coverImageUrl: String? = nil,
        audioUrl: String? = nil,
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
        self.cardTitle = cardTitle
        self.coverImageUrl = coverImageUrl
        self.audioUrl = audioUrl
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

/// 分析阶段详情，如 strategy_matched_n 时的 skills_matched、skill_names
struct AnalysisStageDetail: Codable {
    let skillsMatched: Int?
    let skillNames: [String]?

    enum CodingKeys: String, CodingKey {
        case skillsMatched = "skills_matched"
        case skillNames = "skill_names"
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
    /// 分析阶段
    let analysisStage: String?
    /// 阶段详情，如 {"skills_matched": 3, "skill_names": ["职场丛林"]}
    let analysisStageDetail: AnalysisStageDetail?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case status
        case progress
        case estimatedTimeRemaining = "estimated_time_remaining"
        case updatedAt = "updated_at"
        case failureReason = "failure_reason"
        case analysisStage = "analysis_stage"
        case analysisStageDetail = "analysis_stage_detail"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        status = try container.decode(String.self, forKey: .status)
        progress = try container.decode(Double.self, forKey: .progress)
        estimatedTimeRemaining = try container.decode(Int.self, forKey: .estimatedTimeRemaining)
        failureReason = try container.decodeIfPresent(String.self, forKey: .failureReason)
        analysisStage = try container.decodeIfPresent(String.self, forKey: .analysisStage)
        analysisStageDetail = try container.decodeIfPresent(AnalysisStageDetail.self, forKey: .analysisStageDetail)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }

    // 便利初始化器
    init(sessionId: String, status: String, progress: Double, estimatedTimeRemaining: Int, updatedAt: Date, failureReason: String? = nil, analysisStage: String? = nil, analysisStageDetail: AnalysisStageDetail? = nil) {
        self.sessionId = sessionId
        self.status = status
        self.progress = progress
        self.estimatedTimeRemaining = estimatedTimeRemaining
        self.updatedAt = updatedAt
        self.failureReason = failureReason
        self.analysisStage = analysisStage
        self.analysisStageDetail = analysisStageDetail
    }

    /// 当前阶段的可读描述（用于 UI 展示）
    var stageDisplayText: String? {
        guard let s = analysisStage, !s.isEmpty else { return nil }
        switch s {
        case "upload_done": return "Upload complete"
        case "saving_audio": return "Saving audio…"
        case "transcribing": return "Transcribing…"
        case "matching_profiles": return "Matching profiles…"
        case "strategy_scene": return "Identifying scene…"
        case "strategy_matching": return "Matching skills…"
        case "strategy_matched_n":
            if let n = analysisStageDetail?.skillsMatched {
                return "Matched \(n) skills"
            }
            return "Skills matched"
        case "strategy_executing": return "Processing skills…"
        case "strategy_images": return "Generating images…"
        case "strategy_done": return "Strategy ready"
        case "oss_upload": return "Uploading to cloud…"
        case "gemini_analysis": return "Analyzing conversation…"
        case "voiceprint": return "Matching speakers…"
        default: return nil
        }
    }
}

