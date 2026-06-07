import Foundation

enum EmbeddingError: Error {
    case apiKeyMissing
    case rateLimited
    case networkError(Error)
    case apiError(String)
}

protocol EmbeddingService {
    func embed(text: String) async throws -> [Float]
}
