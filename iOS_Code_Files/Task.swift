import Foundation

// 任务状态枚举
enum TaskStatus: String, Codable {
    case recording = "recording"    // 录制中
    case analyzing = "analyzing"    // 分析中
    case archived = "archived"      // 已归档
    case burned = "burned"          // 已焚毁
}

// 任务数据模型
struct Task: Codable, Identifiable {
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
    
    // 直接初始化方法（用于从TaskDetailResponse创建）
    init(
        id: String,
        title: String,
        startTime: Date,
        endTime: Date?,
        duration: Int,
        tags: [String],
        status: TaskStatus,
        emotionScore: Int?,
        speakerCount: Int?
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


