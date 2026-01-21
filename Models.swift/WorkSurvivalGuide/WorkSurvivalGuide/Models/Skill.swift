//
//  Skill.swift
//  WorkSurvivalGuide
//
//  技能数据模型
//

import Foundation

// 技能数据模型
struct SkillItem: Codable, Identifiable {
    let id: String                    // skill_id
    let name: String                  // 技能名称
    let description: String?          // 技能描述
    let category: String              // 技能分类
    let priority: Int                 // 优先级
    let enabled: Bool                 // 是否启用
    let version: String?              // 版本号
    let metadata: [String: Any]?      // 元数据
    
    // 自定义 CodingKeys 用于处理 API 返回的字段名
    enum CodingKeys: String, CodingKey {
        case id = "skill_id"
        case name
        case description
        case category
        case priority
        case enabled
        case version
        case metadata
    }
    
    // 自定义解码器处理 metadata（可能是字典）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try? container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        priority = try container.decode(Int.self, forKey: .priority)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        version = try? container.decode(String.self, forKey: .version)
        
        // 尝试解码 metadata 为字典（如果存在）
        if container.contains(.metadata) {
            if let metadataDict = try? container.decode([String: AnyCodable].self, forKey: .metadata) {
                metadata = metadataDict.mapValues { $0.value }
            } else {
                metadata = nil
            }
        } else {
            metadata = nil
        }
    }
    
    // 编码器
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(priority, forKey: .priority)
        try container.encode(enabled, forKey: .enabled)
        try container.encodeIfPresent(version, forKey: .version)
        
        if let metadata = metadata {
            let codableMetadata = metadata.mapValues { AnyCodable($0) }
            try container.encode(codableMetadata, forKey: .metadata)
        }
    }
    
    // 便利初始化器
    init(
        id: String,
        name: String,
        description: String? = nil,
        category: String,
        priority: Int,
        enabled: Bool,
        version: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.priority = priority
        self.enabled = enabled
        self.version = version
        self.metadata = metadata
    }
}

// 辅助类型：用于编码/解码 Any 类型
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "无法解码 AnyCodable")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "无法编码 AnyCodable"))
        }
    }
}

// MARK: - API 响应模型

// 技能列表响应
struct SkillListResponse: Codable {
    let skills: [SkillItem]
}

// API 通用响应结构（用于技能列表）
struct SkillsAPIResponse: Codable {
    let code: Int
    let message: String
    let data: SkillListResponse?
    let timestamp: String?
}
