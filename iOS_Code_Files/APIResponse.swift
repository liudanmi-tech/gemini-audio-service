import Foundation

// API 通用响应结构
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: String?
}

// 任务列表响应
struct TaskListResponse: Codable {
    let sessions: [Task]
    let pagination: Pagination
    
    struct Pagination: Codable {
        let page: Int
        let pageSize: Int
        let total: Int
        let totalPages: Int
        
        enum CodingKeys: String, CodingKey {
            case page
            case pageSize = "page_size"
            case total
            case totalPages = "total_pages"
        }
    }
}

// 上传响应
struct UploadResponse: Codable {
    let sessionId: String
    let audioId: String
    let status: String
    let estimatedDuration: Int?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case audioId = "audio_id"
        case status
        case estimatedDuration = "estimated_duration"
    }
}

