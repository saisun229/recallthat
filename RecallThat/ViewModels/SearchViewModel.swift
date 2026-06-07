import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query: String = ""
    var results: [Memory] = []
    var allMemories: [Memory] = []
    var isSearching: Bool = false
    var aiAnswer: String? = nil
    var isAnswering: Bool = false

    private var searchTask: Task<Void, Never>?

    // MARK: - Load

    func loadMemories(from repository: any MemoryRepository) async {
        allMemories = (try? await repository.fetchAll()) ?? []
    }

    // MARK: - Search

    func search(using service: any SearchServiceProtocol) {
        searchTask?.cancel()
        aiAnswer = nil
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            isAnswering = false
            return
        }
        isSearching = true
        let snapshot = allMemories
        searchTask = Task { [weak self] in
            guard let self else { return }
            let found = await service.search(query: trimmed, in: snapshot)
            guard !Task.isCancelled else { return }
            self.results = found
            self.isSearching = false

            // AI answer for question-style queries
            if self.isQuestion(trimmed), !found.isEmpty, APIConfig.hasOpenAIKey {
                self.isAnswering = true
                let llm = OpenAILLMService(apiKey: APIConfig.openAIKey)
                self.aiAnswer = try? await llm.answer(question: trimmed, context: found)
                self.isAnswering = false
            }
        }
    }

    // MARK: - Question detection

    private static let questionPrefixes = [
        "what", "when", "where", "who", "how", "why", "which",
        "is", "are", "can", "does", "do", "did", "was", "were", "will", "should"
    ]

    private func isQuestion(_ text: String) -> Bool {
        if text.hasSuffix("?") { return true }
        let first = text.lowercased().components(separatedBy: .whitespaces).first ?? ""
        return Self.questionPrefixes.contains(first)
    }
}
