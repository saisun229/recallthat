import Foundation

enum EmbeddingStatus: String, Codable {
    case notStarted
    case pending
    case complete
    case failed
}
