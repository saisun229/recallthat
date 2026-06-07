import Foundation

@MainActor
final class DefaultSearchService: SearchServiceProtocol {

    func search(query: String, in memories: [Memory]) async -> [Memory] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        let normalized = trimmed.lowercased()
        return memories.filter { $0.searchText.contains(normalized) }
    }
}
