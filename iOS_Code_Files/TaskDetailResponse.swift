import Foundation

// 对话项模型
struct DialogueItem: Codable {
    let speaker: String
    let content: String
    let tone: String?
    let timestamp: String?
    let isMe: Bool?
    
    enum CodingKeys: String, CodingKey {
        case speaker
        case content
        case tone
        case timestamp
        case isMe = "is_me"
    }
}

// 任务详情响应模型（对应后端的 TaskDetailResponse）
struct TaskDetailResponse: Codable {
    let sessionId: String
    let title: String
    let startTime: String
    let endTime: String?
    let duration: Int
    let tags: [String]
    let status: String
    let emotionScore: Int?
    let speakerCount: Int?
    let dialogues: [DialogueItem]
    let risks: [String]
    let summary: String?
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(String.self, forKey: .startTime)
        endTime = try? container.decode(String.self, forKey: .endTime)
        duration = try container.decode(Int.self, forKey: .duration)
        tags = try container.decode([String].self, forKey: .tags)
        status = try container.decode(String.self, forKey: .status)
        emotionScore = try? container.decode(Int.self, forKey: .emotionScore)
        speakerCount = try? container.decode(Int.self, forKey: .speakerCount)
        dialogues = (try? container.decode([DialogueItem].self, forKey: .dialogues)) ?? []
        risks = (try? container.decode([String].self, forKey: .risks)) ?? []
        summary = try? container.decode(String.self, forKey: .summary)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
    }
}
