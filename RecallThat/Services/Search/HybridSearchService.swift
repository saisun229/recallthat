import Foundation

@MainActor
final class HybridSearchService: SearchServiceProtocol {

    func search(query: String, in memories: [Memory]) async -> [Memory] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let keywordResults = keywordSearch(query: trimmed, in: memories)

        let apiKey = APIConfig.openAIKey
        guard !apiKey.isEmpty, memories.contains(where: { $0.embedding != nil }) else {
            return keywordResults
        }

        guard let queryVector = try? await OpenAIEmbeddingService(apiKey: apiKey).embed(text: trimmed) else {
            return keywordResults
        }

        if Task.isCancelled { return keywordResults }

        let semanticResults: [Memory] = memories
            .compactMap { memory -> (Memory, Float)? in
                guard let emb = memory.embedding else { return nil }
                return (memory, VectorMath.cosineSimilarity(queryVector, emb))
            }
            .sorted { $0.1 > $1.1 }
            .prefix(50)
            .map(\.0)

        return rrfMerge(keyword: keywordResults, semantic: semanticResults)
    }

    // MARK: - Keyword

    private func keywordSearch(query: String, in memories: [Memory]) -> [Memory] {
        let normalized = query.lowercased()
        return memories.filter { $0.searchText.contains(normalized) }
    }

    // MARK: - Reciprocal Rank Fusion

    private func rrfMerge(keyword: [Memory], semantic: [Memory]) -> [Memory] {
        let k: Float = 60
        var scores: [UUID: Float] = [:]
        var byID: [UUID: Memory] = [:]

        for (rank, m) in keyword.enumerated() {
            scores[m.id, default: 0] += 1 / (k + Float(rank + 1))
            byID[m.id] = m
        }
        for (rank, m) in semantic.enumerated() {
            scores[m.id, default: 0] += 1 / (k + Float(rank + 1))
            byID[m.id] = m
        }

        return scores
            .sorted { $0.value > $1.value }
            .compactMap { byID[$0.key] }
    }
}
