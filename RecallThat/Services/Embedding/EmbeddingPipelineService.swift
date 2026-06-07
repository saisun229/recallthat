import Foundation
import UIKit

@MainActor
final class EmbeddingPipelineService {
    private let repository: any MemoryRepository
    private(set) var isRunning = false
    private(set) var lastError: String? = nil
    private var bgTask = UIBackgroundTaskIdentifier.invalid

    init(repository: any MemoryRepository) {
        self.repository = repository
    }

    func processQueue() async {
        guard !isRunning else { return }
        let apiKey = APIConfig.openAIKey
        guard !apiKey.isEmpty else {
            lastError = "OpenAI API key not configured."
            return
        }

        bgTask = UIApplication.shared.beginBackgroundTask(withName: "RecallThat.Embedding") { [weak self] in
            guard let self else { return }
            UIApplication.shared.endBackgroundTask(self.bgTask)
            self.bgTask = .invalid
        }
        defer {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

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
        lastError = nil
    }

    // MARK: - Private

    private func embedSingle(_ memory: Memory, using service: any EmbeddingService) async -> Bool {
        // Skip the intermediate .pending save — only one write per item to reduce main-thread stalls.
        var updated = memory

        do {
            updated.embedding = try await service.embed(text: memory.searchText)
            updated.embeddingStatus = .complete
            lastError = nil
            try? await repository.update(updated)
            return true
        } catch EmbeddingError.apiKeyMissing {
            updated.embeddingStatus = .notStarted
            lastError = "OpenAI API key is missing or invalid."
            try? await repository.update(updated)
            return false
        } catch EmbeddingError.rateLimited {
            updated.embeddingStatus = .notStarted
            lastError = "OpenAI rate limit reached. Embeddings will retry next time."
            try? await repository.update(updated)
            return false
        } catch EmbeddingError.networkError {
            updated.embeddingStatus = .notStarted
            lastError = "No internet connection. Semantic search will be available when you're back online."
            try? await repository.update(updated)
            return false
        } catch EmbeddingError.apiError(let msg) {
            updated.embeddingStatus = .failed
            lastError = "OpenAI error: \(msg)"
            try? await repository.update(updated)
            return true
        } catch {
            updated.embeddingStatus = .failed
            lastError = error.localizedDescription
            try? await repository.update(updated)
            return true
        }
    }
}
