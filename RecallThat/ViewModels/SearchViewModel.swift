import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query: String = ""
    var results: [Memory] = []
    var allMemories: [Memory] = []

    func loadMemories(from repository: any MemoryRepository) async {
        allMemories = (try? await repository.fetchAll()) ?? []
    }

    func search(using service: any SearchServiceProtocol) {
        results = service.search(query: query, in: allMemories)
    }
}
