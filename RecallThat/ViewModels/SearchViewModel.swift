import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query: String = ""
    var results: [Memory] = []
    var allMemories: [Memory] = []
    var isSearching: Bool = false

    private var searchTask: Task<Void, Never>?

    // MARK: - Load

    func loadMemories(from repository: any MemoryRepository) async {
        allMemories = (try? await repository.fetchAll()) ?? []
    }

    // MARK: - Search

    func search(using service: any SearchServiceProtocol) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        let snapshot = allMemories
        searchTask = Task { [weak self] in
            guard let self else { return }
            // Debounce — prevents per-keystroke embedding API calls
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let found = await service.search(query: trimmed, in: snapshot)
            guard !Task.isCancelled else { return }
            self.results = found
            self.isSearching = false
        }
    }

}
