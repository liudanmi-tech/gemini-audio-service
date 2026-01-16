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

// 策略分析响应模型
struct StrategyAnalysisResponse: Codable {
    let visual: [VisualData]
    let strategies: [StrategyItem]
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
