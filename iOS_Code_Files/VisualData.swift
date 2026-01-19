import Foundation

// 视觉数据模型（对应后端的 VisualData）
struct VisualData: Codable, Identifiable {
    var id: String { "\(transcriptIndex)" }  // 使用 transcript_index 作为 id
    let transcriptIndex: Int
    let speaker: String
    let imagePrompt: String
    let emotion: String
    let subtext: String
    let context: String
    let myInner: String
    let otherInner: String
    let imageUrl: String?
    let imageBase64: String?
    
    enum CodingKeys: String, CodingKey {
        case transcriptIndex = "transcript_index"
        case speaker
        case imagePrompt = "image_prompt"
        case emotion
        case subtext
        case context
        case myInner = "my_inner"
        case otherInner = "other_inner"
        case imageUrl = "image_url"
        case imageBase64 = "image_base64"
    }
}

// 应用的技能信息
struct AppliedSkill: Codable, Identifiable {
    let id: String  // 使用 skill_id 作为 id
    let skillId: String
    let priority: Int
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case priority
        case confidence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skillId = try container.decode(String.self, forKey: .skillId)
        id = skillId  // 使用 skill_id 作为 id
        priority = try container.decode(Int.self, forKey: .priority)
        confidence = try? container.decode(Double.self, forKey: .confidence)
    }
}

// 策略分析响应模型
struct StrategyAnalysisResponse: Codable {
    let visual: [VisualData]
    let strategies: [StrategyItem]
    let appliedSkills: [AppliedSkill]?
    let sceneCategory: String?
    let sceneConfidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case visual
        case strategies
        case appliedSkills = "applied_skills"
        case sceneCategory = "scene_category"
        case sceneConfidence = "scene_confidence"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visual = try container.decode([VisualData].self, forKey: .visual)
        strategies = try container.decode([StrategyItem].self, forKey: .strategies)
        appliedSkills = try? container.decode([AppliedSkill].self, forKey: .appliedSkills)
        sceneCategory = try? container.decode(String.self, forKey: .sceneCategory)
        
        // scene_confidence 可能是 Double 或 JSON 对象，尝试多种解码方式
        if let doubleValue = try? container.decode(Double.self, forKey: .sceneConfidence) {
            sceneConfidence = doubleValue
        } else {
            sceneConfidence = nil
        }
    }
}

// 策略项模型（对应后端的 StrategyItem）
struct StrategyItem: Codable, Identifiable {
    let id: String  // 使用 title 作为 id
    let title: String
    let content: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        id = title  // 使用 title 作为 id
        content = try container.decode(String.self, forKey: .content)
    }
}
