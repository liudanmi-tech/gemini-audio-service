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

// 命中的技能模型（对应后端 applied_skills）
struct AppliedSkill: Codable, Identifiable {
    let skillId: String
    let priority: Int
    let confidence: Double?
    var id: String { skillId }
    
    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case priority
        case confidence
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
    
    init(visual: [VisualData], strategies: [StrategyItem], appliedSkills: [AppliedSkill]? = nil, sceneCategory: String? = nil, sceneConfidence: Double? = nil) {
        self.visual = visual
        self.strategies = strategies
        self.appliedSkills = appliedSkills
        self.sceneCategory = sceneCategory
        self.sceneConfidence = sceneConfidence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visual = try container.decode([VisualData].self, forKey: .visual)
        strategies = try container.decode([StrategyItem].self, forKey: .strategies)
        appliedSkills = try? container.decode([AppliedSkill].self, forKey: .appliedSkills)
        sceneCategory = try? container.decode(String.self, forKey: .sceneCategory)
        sceneConfidence = (try? container.decode(Double.self, forKey: .sceneConfidence))
            ?? (try? container.decode(Float.self, forKey: .sceneConfidence)).map { Double($0) }
    }
}

// 策略项模型（对应后端的 StrategyItem）
struct StrategyItem: Codable, Identifiable {
    let id: String  // 使用 title 作为 id
    let title: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case title
        case content
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        id = title  // 使用 title 作为 id
        content = try container.decode(String.self, forKey: .content)
    }
}

// 图片 URL 转换工具
// 由于 OSS bucket 是私有的，需要将 OSS URL 转换为后端 API URL
extension VisualData {
    /// 获取可访问的图片 URL
    /// 如果 imageUrl 是 OSS URL，转换为后端 API URL
    /// 如果 imageUrl 是后端 API URL，直接返回
    /// 如果没有 imageUrl，返回 nil
    func getAccessibleImageURL(baseURL: String) -> String? {
        guard let imageUrl = imageUrl else {
            print("⚠️ [VisualData] imageUrl 为 nil")
            return nil
        }
        
        print("🔄 [VisualData] 转换图片 URL:")
        print("  原始 URL: \(imageUrl)")
        print("  baseURL: \(baseURL)")
        
        // 如果已经是后端 API URL，直接返回
        if imageUrl.contains("/api/v1/images/") {
            print("✅ [VisualData] 已经是后端 API URL，直接返回")
            return imageUrl
        }
        
        // 如果是 OSS URL，提取 session_id 和 image_index，转换为后端 API URL
        // OSS 路径格式: images/{user_id}/{session_id}/{image_index}.png
        // baseURL 已含 /api/v1，故 API URL = {baseURL}/images/{session_id}/{image_index}
        if imageUrl.contains("/images/") {
            if let pathRange = imageUrl.range(of: "/images/") {
                let path = String(imageUrl[pathRange.upperBound...])
                let parts = path.components(separatedBy: "/")
                // path = "user_id/session_id/0.png" -> parts = [user_id, session_id, 0.png]
                if parts.count >= 3 {
                    let sessionId = parts[1]
                    let indexPart = parts[2].replacingOccurrences(of: ".png", with: "")
                    let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
                    let convertedURL = "\(base)/images/\(sessionId)/\(indexPart)"
                    print("✅ [VisualData] OSS URL 转换成功:")
                    print("  转换后 URL: \(convertedURL)")
                    return convertedURL
                }
            }
        }
        
        // 如果无法转换，返回原始 URL（可能会失败，但至少尝试）
        print("⚠️ [VisualData] 无法识别 URL 格式，返回原始 URL")
        return imageUrl
    }
}
