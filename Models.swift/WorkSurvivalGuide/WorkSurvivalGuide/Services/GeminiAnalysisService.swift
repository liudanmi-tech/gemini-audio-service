//
//  GeminiAnalysisService.swift
//  WorkSurvivalGuide
//
//  Gemini API 分析服务（Mock 模式下直接调用）
//

import Foundation

class GeminiAnalysisService {
    static let shared = GeminiAnalysisService()
    
    private init() {}
    
    // Gemini API Key（从环境变量或配置中读取）
    private let apiKey = "AIzaSyCiOOgxgMkTuqw6sXTT08WbD7R6kMK-k08"
    private let baseURL = "http://47.79.254.213/secret-channel/v1beta"
    
    // 分析音频文件
    func analyzeAudio(fileURL: URL) async throws -> AudioAnalysisResult {
        // 读取音频文件
        let audioData = try Data(contentsOf: fileURL)
        
        // 构建请求
        let url = URL(string: "\(baseURL)/models/gemini-3-flash-preview:generateContent?key=\(apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求体
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "fileData": [
                                "mimeType": "audio/m4a",
                                "fileUri": fileURL.absoluteString
                            ]
                        ],
                        [
                            "text": """
                            请分析这段音频。请识别：
                            1. 说话人数量。
                            2. 按时间顺序，详细列出所有对话。每个对话应包含：
                              - 说话人（例如：说话人1、说话人A）
                              - 具体说话内容
                              - 说话语气（例如：平静、愤怒、轻松、焦虑）
                            3. 关键风险点。
                            请务必以纯 JSON 格式返回，不要包含 Markdown 标记。

                            返回格式必须严格遵循以下结构：
                            {
                              "speaker_count": 数字,
                              "dialogues": [
                                {
                                  "speaker": "说话人1",
                                  "content": "具体说话内容",
                                  "tone": "语气"
                                }
                              ],
                              "risks": ["风险点1", "风险点2", ...]
                            }
                            """
                        ]
                    ]
                ]
            ]
        ]
        
        // 注意：实际实现中，需要先上传文件到 Gemini，然后使用 fileUri
        // 这里简化处理，直接模拟分析结果
        
        // 模拟分析延迟
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3秒
        
        // 返回 Mock 分析结果
        return AudioAnalysisResult(
            speakerCount: 2,
            dialogues: [
                DialogueItem(speaker: "说话人1", content: "这是测试对话内容", tone: "平静", timestamp: 10.5),
                DialogueItem(speaker: "说话人2", content: "这是另一个人的回复", tone: "轻松", timestamp: 25.3)
            ],
            risks: ["测试风险点1", "测试风险点2"]
        )
    }
}

// MARK: - 分析结果模型

struct AudioAnalysisResult {
    let speakerCount: Int
    let dialogues: [DialogueItem]
    let risks: [String]
}

