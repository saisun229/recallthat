import Foundation

@MainActor
final class HybridSearchService: SearchServiceProtocol {

    func search(query: String, in memories: [Memory]) async -> [Memory] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let keywordResults = keywordSearch(query: trimmed, in: memories)

        guard APIConfig.aiFeaturesEnabled else {
            // No API key, or user hasn't consented to sharing OCR text with OpenAI — keyword results only
            return Array(keywordResults.prefix(20))
        }
        let apiKey = APIConfig.openAIKey

        guard let queryVector = try? await OpenAIEmbeddingService(apiKey: apiKey).embed(text: trimmed) else {
            return Array(keywordResults.prefix(20))
        }

        if Task.isCancelled { return Array(keywordResults.prefix(20)) }

        let semanticResults: [Memory] = memories
            .compactMap { memory -> (Memory, Float)? in
                guard let emb = memory.embedding else { return nil }
                let sim = VectorMath.cosineSimilarity(queryVector, emb)
                guard sim > 0.0 else { return nil }
                return (memory, sim)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(50)
            .map(\.0)

        let merged = rrfMerge(keyword: keywordResults, semantic: semanticResults)
        return Array(merged.prefix(20))
    }

    // MARK: - Keyword search

    // Tokenize into meaningful words, filter stop words, rank by number of tokens that match.
    private func keywordSearch(query: String, in memories: [Memory]) -> [Memory] {
        let tokens = queryTokens(query)
        guard !tokens.isEmpty else { return [] }

        return memories
            .compactMap { memory -> (Memory, Int)? in
                let text = memory.searchText // already lowercased
                let matchCount = tokens.filter { text.contains($0) }.count
                guard matchCount > 0 else { return nil }
                return (memory, matchCount)
            }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    private func queryTokens(_ query: String) -> [String] {
        query
            .lowercased()
            .components(separatedBy: .init(charactersIn: " \t\n,.!?;:\"'()[]{}"))
            .filter { $0.count > 2 && !Self.stopWords.contains($0) }
    }

    private static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
        "have", "has", "had", "do", "does", "did", "will", "would", "could",
        "should", "may", "might", "i", "my", "me", "we", "our", "you", "your",
        "what", "when", "where", "who", "why", "how", "which", "that", "this",
        "it", "its", "any", "all", "some", "not", "no", "about", "up", "out",
        "there", "here", "so", "if", "then", "than", "just", "also", "can",
        "get", "got", "like", "more", "most", "other", "into", "over", "after",
        "did", "save", "saved", "show", "find", "tell", "want"
    ]

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
