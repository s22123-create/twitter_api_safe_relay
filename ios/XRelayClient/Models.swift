import Foundation

struct TimelinePost {
    let id: String
    let name: String
    let handle: String
    let text: String
    let avatarURL: URL?
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)
    case missingOperation(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "リレーURLが正しくありません。"
        case .invalidResponse: return "リレーから不正な応答が返されました。"
        case .server(let message): return message
        case .missingOperation(let name): return "リクエストカタログに \(name) がありません。"
        }
    }
}
