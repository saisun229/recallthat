import Foundation

protocol LLMService {
    func answer(query: String, context: [Memory]) async throws -> String
}
