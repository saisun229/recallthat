import Foundation

protocol LLMService {
    func answer(question: String, context: [Memory]) async throws -> String
}
