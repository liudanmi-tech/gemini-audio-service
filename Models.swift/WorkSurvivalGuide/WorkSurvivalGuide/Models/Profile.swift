//
//  Profile.swift
//  WorkSurvivalGuide
//
//  档案数据模型
//

import Foundation

// 档案数据模型
struct Profile: Codable, Identifiable {
    let id: String
    var name: String              // 档案人名称
    var relationship: String      // 关系（自己、死党、领导等）
    var photoUrl: String?         // 照片URL（可选）
    var notes: String?            // 备注
    var audioSessionId: String?   // 关联的对话session_id
    var audioSegmentId: String?   // 音频片段ID（用于标识从对话中提取的片段）
    var audioStartTime: Double?   // 音频片段开始时间（秒）
    var audioEndTime: Double?     // 音频片段结束时间（秒）
    var audioUrl: String?         // 音频片段URL
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case relationship
        case photoUrl = "photo_url"
        case notes
        case audioSessionId = "audio_session_id"
        case audioSegmentId = "audio_segment_id"
        case audioStartTime = "audio_start_time"
        case audioEndTime = "audio_end_time"
        case audioUrl = "audio_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 自定义日期解码器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        relationship = try container.decode(String.self, forKey: .relationship)
        photoUrl = try? container.decode(String.self, forKey: .photoUrl)
        notes = try? container.decode(String.self, forKey: .notes)
        audioSessionId = try? container.decode(String.self, forKey: .audioSessionId)
        audioSegmentId = try? container.decode(String.self, forKey: .audioSegmentId)
        audioStartTime = try? container.decode(Double.self, forKey: .audioStartTime)
        audioEndTime = try? container.decode(Double.self, forKey: .audioEndTime)
        audioUrl = try? container.decode(String.self, forKey: .audioUrl)
        
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        createdAt = dateFormatter.date(from: createdAtString) ?? Date()
        updatedAt = dateFormatter.date(from: updatedAtString) ?? Date()
    }
    
    // 编码器
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(relationship, forKey: .relationship)
        try container.encodeIfPresent(photoUrl, forKey: .photoUrl)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(audioSessionId, forKey: .audioSessionId)
        try container.encodeIfPresent(audioSegmentId, forKey: .audioSegmentId)
        try container.encodeIfPresent(audioStartTime, forKey: .audioStartTime)
        try container.encodeIfPresent(audioEndTime, forKey: .audioEndTime)
        try container.encodeIfPresent(audioUrl, forKey: .audioUrl)
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(dateFormatter.string(from: createdAt), forKey: .createdAt)
        try container.encode(dateFormatter.string(from: updatedAt), forKey: .updatedAt)
    }
    
    // 便利初始化器
    init(
        id: String,
        name: String,
        relationship: String,
        photoUrl: String? = nil,
        notes: String? = nil,
        audioSessionId: String? = nil,
        audioSegmentId: String? = nil,
        audioStartTime: Double? = nil,
        audioEndTime: Double? = nil,
        audioUrl: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.photoUrl = photoUrl
        self.notes = notes
        self.audioSessionId = audioSessionId
        self.audioSegmentId = audioSegmentId
        self.audioStartTime = audioStartTime
        self.audioEndTime = audioEndTime
        self.audioUrl = audioUrl
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// 档案照片 URL 转换（OSS 私有，需转 API URL）
extension Profile {
    /// 获取可访问的档案照片 URL（含 cacheBuster 防止修改后不刷新）
    func getAccessiblePhotoURL(baseURL: String, cacheBuster: String? = nil) -> String? {
        guard var url = Self.getAccessiblePhotoURL(photoUrl: photoUrl, baseURL: baseURL) else { return nil }
        let ts = cacheBuster ?? "\(Int(updatedAt.timeIntervalSince1970))"
        url += (url.contains("?") ? "&" : "?") + "t=\(ts)"
        return url
    }
    static func getAccessiblePhotoURL(photoUrl: String?, baseURL: String, cacheBuster: String? = nil) -> String? {
        guard let photoUrl = photoUrl, !photoUrl.isEmpty else { return nil }
        var url: String
        if photoUrl.contains("/api/v1/images/") { url = photoUrl.components(separatedBy: "?").first ?? photoUrl }
        else if photoUrl.contains("/images/"), let pathRange = photoUrl.range(of: "/images/") {
            let path = String(photoUrl[pathRange.upperBound...])
            let parts = path.components(separatedBy: "/")
            if parts.count >= 3 {
                let sessionId = parts[1].components(separatedBy: "?").first ?? parts[1]
                let indexPart = (parts[2].components(separatedBy: ".").first ?? parts[2]).replacingOccurrences(of: ".png", with: "")
                let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
                url = "\(base)/images/\(sessionId)/\(indexPart)"
            } else { url = photoUrl }
        } else { url = photoUrl }
        if let cb = cacheBuster, !cb.isEmpty {
            url += (url.contains("?") ? "&" : "?") + "t=\(cb)"
        }
        return url
    }
}

// 音频片段数据模型
struct AudioSegment: Codable, Identifiable {
    let id: String
    let sessionId: String         // 所属对话session_id
    let speaker: String           // 说话人标识
    let startTime: Double         // 开始时间（秒）
    let endTime: Double           // 结束时间（秒）
    let duration: Double          // 时长（秒）
    let content: String           // 对话内容
    let audioUrl: String?         // 音频片段URL（后端生成）
    
    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case speaker
        case startTime = "start_time"
        case endTime = "end_time"
        case duration
        case content
        case audioUrl = "audio_url"
    }
    
    // 便利初始化器
    init(
        id: String,
        sessionId: String,
        speaker: String,
        startTime: Double,
        endTime: Double,
        duration: Double,
        content: String,
        audioUrl: String? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.speaker = speaker
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.content = content
        self.audioUrl = audioUrl
    }
    
    // 格式化时长显示
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
}

// MARK: - API 响应模型

// 档案列表响应
struct ProfileListResponse: Codable {
    let profiles: [Profile]
}

// 音频片段列表响应
struct AudioSegmentListResponse: Codable {
    let segments: [AudioSegment]
}

// 音频片段提取响应
struct AudioSegmentExtractResponse: Codable {
    let segmentId: String
    let audioUrl: String
    let duration: Double
    
    enum CodingKeys: String, CodingKey {
        case segmentId = "segment_id"
        case audioUrl = "audio_url"
        case duration
    }
}
