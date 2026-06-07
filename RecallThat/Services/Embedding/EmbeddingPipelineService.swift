import Foundation

@MainActor
final class EmbeddingPipelineService {
    private let repository: any MemoryRepository
    private(set) var isRunning = false

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    func processQueue() async {
        guard !isRunning else { return }
        let apiKey = APIConfig.openAIKey
        guard !apiKey.isEmpty else { return }

        isRunning = true
        defer { isRunning = false }

        let service = OpenAIEmbeddingService(apiKey: apiKey)
        guard let memories = try? await repository.fetchAll() else { return }

        let pending = memories.filter {
            $0.ocrStatus == .complete &&
            $0.embeddingStatus == .notStarted &&
            !$0.searchText.isEmpty
        }

        for memory in pending {
            let shouldContinue = await embedSingle(memory, using: service)
            if !shouldContinue { break }
        }
    }

    func resetFailedEmbeddings() async {
        guard let memories = try? await repository.fetchAll() else { return }
        for memory in memories where memory.embeddingStatus == .failed {
            var updated = memory
            updated.embeddingStatus = .notStarted
            try? await repository.update(updated)
        }
    }

    private func embedSingle(_ memory: Memory, using service: any EmbeddingService) async -> Bool {
        var updated = memory
        updated.embeddingStatus = .pending
        try? await repository.update(updated)

        do {
            updated.embedding = try await service.embed(text: memory.searchText)
            updated.embeddingStatus = .complete
        } catch EmbeddingError.apiKeyMissing, EmbeddingError.rateLimited {
            updated.embeddingStatus = .notStarted
            try? await repository.update(updated)
            return false
        } catch {
            updated.embeddingStatus = .failed
        }

        try? await repository.update(updated)
        return true
    }
}
