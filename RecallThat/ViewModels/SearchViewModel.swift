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

            // AI response for any query with results
            if !found.isEmpty, APIConfig.hasOpenAIKey {
                self.isAnswering = true
                let llm = OpenAILLMService(apiKey: APIConfig.openAIKey)
                self.aiAnswer = try? await llm.answer(query: trimmed, context: found)
                self.isAnswering = false
            }
        }
    }

}
