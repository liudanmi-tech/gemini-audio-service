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

// 技能卡片内容：策略型
struct SkillCardStrategyContent: Codable {
    let visual: [VisualData]?
    let strategies: [StrategyItem]?
    
    enum CodingKeys: String, CodingKey {
        case visual
        case strategies
    }
}

// 技能卡片内容：防抑郁监控型
struct SkillCardMentalHealthContent: Codable {
    let defenseEnergyPct: Int
    let dominantDefense: String
    let statusAssessment: String
    let cognitiveTriad: CognitiveTriad?
    let insight: String
    let strategy: String
    let crisisAlert: Bool
    
    enum CodingKeys: String, CodingKey {
        case defenseEnergyPct = "defense_energy_pct"
        case dominantDefense = "dominant_defense"
        case statusAssessment = "status_assessment"
        case cognitiveTriad = "cognitive_triad"
        case insight
        case strategy
        case crisisAlert = "crisis_alert"
    }
}

struct CognitiveTriad: Codable {
    let selfStatus: TriadItem?
    let world: TriadItem?
    let future: TriadItem?
    
    enum CodingKeys: String, CodingKey {
        case selfStatus = "self"
        case world
        case future
    }
}

struct TriadItem: Codable {
    let status: String  // red | yellow | green
    let reason: String
}

// 技能卡片内容：情绪型
struct SkillCardEmotionContent: Codable {
    let sighCount: Int
    let hahaCount: Int
    let moodState: String
    let moodEmoji: String
    let charCount: Int
    
    enum CodingKeys: String, CodingKey {
        case sighCount = "sigh_count"
        case hahaCount = "haha_count"
        case moodState = "mood_state"
        case moodEmoji = "mood_emoji"
        case charCount = "char_count"
    }
}

// 技能卡片（多技能滑动卡片）
struct SkillCard: Codable, Identifiable {
    var id: String { skillId }
    let skillId: String
    let skillName: String
    let contentType: String  // "strategy" | "emotion" | "mental_health"
    let category: String?
    let dimension: String?
    let matchedSubSkill: String?
    let content: SkillCardContent?
    
    init(skillId: String, skillName: String, contentType: String, category: String? = nil, dimension: String? = nil, matchedSubSkill: String? = nil, content: SkillCardContent? = nil) {
        self.skillId = skillId
        self.skillName = skillName
        self.contentType = contentType
        self.category = category
        self.dimension = dimension
        self.matchedSubSkill = matchedSubSkill
        self.content = content
    }
    
    enum CodingKeys: String, CodingKey {
        case skillId = "skill_id"
        case skillName = "skill_name"
        case contentType = "content_type"
        case category
        case dimension
        case matchedSubSkill = "matched_sub_skill"
        case content
    }
    
    /// 用于手风琴面板标题：优先显示 matchedSubSkill（与技能库名称一致），其次 skillName
    var accordionTitle: String {
        if let sub = matchedSubSkill, !sub.isEmpty {
            return sub
        }
        return skillName
    }
    
    /// 归属的顶级场景（用于 Tab 分组）
    var sceneCategory: String {
        switch category ?? "" {
        case "workplace": return "职场"
        case "family": return "家庭"
        case "emotion", "personal": return "个人"
        default: return "职场"
        }
    }
}

// 技能卡片内容（支持 strategy / emotion / mental_health），统一解码后按 contentType 使用
struct SkillCardContent: Codable {
    let sighCount: Int?
    let hahaCount: Int?
    let moodState: String?
    let moodEmoji: String?
    let charCount: Int?
    let visual: [VisualData]?
    let strategies: [StrategyItem]?
    let defenseEnergyPct: Int?
    let dominantDefense: String?
    let statusAssessment: String?
    let cognitiveTriad: CognitiveTriad?
    let insight: String?
    let strategy: String?
    let crisisAlert: Bool?
    
    enum CodingKeys: String, CodingKey {
        case sighCount = "sigh_count"
        case hahaCount = "haha_count"
        case moodState = "mood_state"
        case moodEmoji = "mood_emoji"
        case charCount = "char_count"
        case visual
        case strategies
        case defenseEnergyPct = "defense_energy_pct"
        case dominantDefense = "dominant_defense"
        case statusAssessment = "status_assessment"
        case cognitiveTriad = "cognitive_triad"
        case insight
        case strategy
        case crisisAlert = "crisis_alert"
    }
    
    var isMentalHealth: Bool { defenseEnergyPct != nil || insight != nil }
    var mentalHealthContent: SkillCardMentalHealthContent? {
        guard isMentalHealth else { return nil }
        return SkillCardMentalHealthContent(
            defenseEnergyPct: defenseEnergyPct ?? 50,
            dominantDefense: dominantDefense ?? "",
            statusAssessment: statusAssessment ?? "",
            cognitiveTriad: cognitiveTriad,
            insight: insight ?? "",
            strategy: strategy ?? "",
            crisisAlert: crisisAlert ?? false
        )
    }
    
    var isEmotion: Bool { moodState != nil || moodEmoji != nil }
    var emotionContent: SkillCardEmotionContent? {
        guard isEmotion else { return nil }
        return SkillCardEmotionContent(
            sighCount: sighCount ?? 0,
            hahaCount: hahaCount ?? 0,
            moodState: moodState ?? "平常心",
            moodEmoji: moodEmoji ?? "😐",
            charCount: charCount ?? 0
        )
    }
    var strategyContent: SkillCardStrategyContent? {
        guard visual != nil || strategies != nil else { return nil }
        return SkillCardStrategyContent(visual: visual, strategies: strategies)
    }
}

// 场景图片模型（对应后端 scene_images，由 scene_image_generator 并行生成）
struct SceneImage: Codable, Identifiable {
    let index: Int
    let sceneDescription: String
    let imageUrl: String?
    let imageBase64: String?

    var id: String { "\(index)" }

    enum CodingKeys: String, CodingKey {
        case index
        case sceneDescription = "scene_description"
        case imageUrl = "image_url"
        case imageBase64 = "image_base64"
    }

    /// 获取可访问的图片 URL（将私有 OSS URL 转换为后端 API 代理 URL）
    /// baseURL 示例: "http://47.79.254.213/api/v1"
    func getAccessibleImageURL(baseURL: String) -> String? {
        guard let urlString = imageUrl, !urlString.isEmpty else { return nil }
        // 如果已经是后端 API URL，直接返回
        if urlString.contains("/api/v1/images/") { return urlString }
        // OSS URL 格式: images/{user_id}/{session_id}/{image_index}.png
        if urlString.contains("/images/"), let pathRange = urlString.range(of: "/images/") {
            let path = String(urlString[pathRange.upperBound...])
            let parts = path.components(separatedBy: "/")
            if parts.count >= 3 {
                let sessionId = parts[1]
                let indexPart = parts[2].replacingOccurrences(of: ".png", with: "")
                let base = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
                return "\(base)/images/\(sessionId)/\(indexPart)"
            }
        }
        return urlString
    }
}

// 策略分析响应模型
struct StrategyAnalysisResponse: Codable {
    let visual: [VisualData]
    let strategies: [StrategyItem]
    let appliedSkills: [AppliedSkill]?
    let sceneCategory: String?
    let sceneConfidence: Double?
    let skillCards: [SkillCard]?
    let matchedScenes: [String]?
    let sceneImages: [SceneImage]?

    enum CodingKeys: String, CodingKey {
        case visual
        case strategies
        case appliedSkills = "applied_skills"
        case sceneCategory = "scene_category"
        case sceneConfidence = "scene_confidence"
        case skillCards = "skill_cards"
        case matchedScenes = "matched_scenes"
        case sceneImages = "scene_images"
    }

    init(visual: [VisualData], strategies: [StrategyItem], appliedSkills: [AppliedSkill]? = nil, sceneCategory: String? = nil, sceneConfidence: Double? = nil, skillCards: [SkillCard]? = nil, matchedScenes: [String]? = nil, sceneImages: [SceneImage]? = nil) {
        self.visual = visual
        self.strategies = strategies
        self.appliedSkills = appliedSkills
        self.sceneCategory = sceneCategory
        self.sceneConfidence = sceneConfidence
        self.skillCards = skillCards
        self.matchedScenes = matchedScenes
        self.sceneImages = sceneImages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        visual = try container.decode([VisualData].self, forKey: .visual)
        strategies = try container.decode([StrategyItem].self, forKey: .strategies)
        appliedSkills = try? container.decode([AppliedSkill].self, forKey: .appliedSkills)
        sceneCategory = try? container.decode(String.self, forKey: .sceneCategory)
        sceneConfidence = (try? container.decode(Double.self, forKey: .sceneConfidence))
            ?? (try? container.decode(Float.self, forKey: .sceneConfidence)).map { Double($0) }
        skillCards = try? container.decode([SkillCard].self, forKey: .skillCards)
        matchedScenes = try? container.decode([String].self, forKey: .matchedScenes)
        sceneImages = try? container.decode([SceneImage].self, forKey: .sceneImages)
    }
}

// 策略项模型（对应后端的 StrategyItem，含 id/label/emoji/title/content）
struct StrategyItem: Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let emoji: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case emoji
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        id = (try? container.decode(String.self, forKey: .id)) ?? title
        emoji = try? container.decode(String.self, forKey: .emoji)
    }
}

// 心情趋势点（emotion-trend API）
struct EmotionTrendPoint: Codable, Identifiable {
    var id: String { "\(sessionId)_\(createdAt ?? "")" }
    let sessionId: String
    let createdAt: String?
    let moodState: String
    let moodEmoji: String
    let sighCount: Int
    let hahaCount: Int
    let charCount: Int
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case createdAt = "created_at"
        case moodState = "mood_state"
        case moodEmoji = "mood_emoji"
        case sighCount = "sigh_count"
        case hahaCount = "haha_count"
        case charCount = "char_count"
    }
    
    init(sessionId: String, createdAt: String?, moodState: String, moodEmoji: String, sighCount: Int, hahaCount: Int, charCount: Int) {
        self.sessionId = sessionId
        self.createdAt = createdAt
        self.moodState = moodState
        self.moodEmoji = moodEmoji
        self.sighCount = sighCount
        self.hahaCount = hahaCount
        self.charCount = charCount
    }
}

struct EmotionTrendResponse: Codable {
    let points: [EmotionTrendPoint]
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

// 顶级场景分类
enum SceneCategory: String, CaseIterable {
    case workplace = "职场"
    case family = "家庭"
    case personal = "个人"
    
    var icon: String {
        switch self {
        case .workplace: return "briefcase.fill"
        case .family: return "house.fill"
        case .personal: return "person.fill"
        }
    }
    
    static func from(displayName: String) -> SceneCategory? {
        return allCases.first { $0.rawValue == displayName }
    }
}

// 职场维度枚举
enum WorkplaceDimension: String, CaseIterable {
    case rolePosition = "role_position"
    case scenario = "scenario"
    case psychology = "psychology"
    case careerStage = "career_stage"
    case capability = "capability"
    
    var displayName: String {
        switch self {
        case .rolePosition: return "角色方位"
        case .scenario: return "场景情境"
        case .psychology: return "心理风格"
        case .careerStage: return "职业阶段"
        case .capability: return "能力维度"
        }
    }
    
    var icon: String {
        switch self {
        case .rolePosition: return "arrow.up.arrow.down"
        case .scenario: return "theatermasks.fill"
        case .psychology: return "brain.head.profile"
        case .careerStage: return "chart.line.uptrend.xyaxis"
        case .capability: return "star.fill"
        }
    }
    
    static func from(key: String) -> WorkplaceDimension? {
        return allCases.first { $0.rawValue == key }
    }
}
