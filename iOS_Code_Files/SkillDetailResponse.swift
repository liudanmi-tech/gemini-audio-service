import Foundation

// 技能详情响应模型
struct SkillDetailResponse: Codable {
    let skillId: String
    let name: String
    let description: String?
    let category: String
    let skillPath: String
    let priority: Int
    let enabled: Bool
    let version: String?
    let metadata: [String: Any]?
    let content: String?  // SKILL.md 完整内容
    let promptTemplate: String?  // Prompt 模板
    let knowledgeBase: String?  // 知识库内容
    
    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case name
        case description
        case category
        case skillPath = "skill_path"
        case priority
        case enabled
        case version
        case metadata
        case content
        case promptTemplate = "prompt_template"
        case knowledgeBase = "knowledge_base"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skillId = try container.decode(String.self, forKey: .skillId)
        name = try container.decode(String.self, forKey: .name)
        description = try? container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        skillPath = try container.decode(String.self, forKey: .skillPath)
        priority = try container.decode(Int.self, forKey: .priority)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        version = try? container.decode(String.self, forKey: .version)
        
        // metadata 可能是字典，使用 AnyCodable 处理
        if let metadataDict = try? container.decode([String: AnyCodable].self, forKey: .metadata) {
            metadata = metadataDict.mapValues { $0.value }
        } else {
            metadata = nil
        }
        
        content = try? container.decode(String.self, forKey: .content)
        promptTemplate = try? container.decode(String.self, forKey: .promptTemplate)
        knowledgeBase = try? container.decode(String.self, forKey: .knowledgeBase)
    }
}

// 辅助类型，用于解码任意 JSON 值
private struct AnyCodable: Codable {
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
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解码 AnyCodable"
            )
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
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "无法编码 AnyCodable")
            )
        }
    }
}
