import Foundation
import Observation

@MainActor
@Observable
final class AppEnvironment {
    let memoryRepository: any MemoryRepository
    let photoLibraryService: any PhotoLibraryServiceProtocol
    let photoImportService: PhotoImportService
    let ocrPipelineService: OCRPipelineService
    let searchService: any SearchServiceProtocol
    let embeddingPipelineService: EmbeddingPipelineService

    /// Incremented whenever memories are bulk-modified so views that hold their own copy re-fetch.
    var memoriesVersion: Int = 0

    // MARK: - Background indexing state (observable by all tabs)

    private(set) var isOCRRunning = false
    private(set) var ocrProgress: OCRProgress? = nil

    var isEmbeddingRunning: Bool { embeddingPipelineService.isRunning }
    var embeddingError: String? { embeddingPipelineService.lastError }

    struct OCRProgress {
        let completed: Int
        let total: Int
        var description: String {
            total > 0 ? "Indexing \(completed)/\(total)…" : "Indexing…"
        }
    }

    init(
        repository: any MemoryRepository,
        photoLibraryService: any PhotoLibraryServiceProtocol,
        photoImportService: PhotoImportService,
        ocrPipelineService: OCRPipelineService,
        searchService: any SearchServiceProtocol,
        embeddingPipelineService: EmbeddingPipelineService
    ) {
        self.memoryRepository = repository
        self.photoLibraryService = photoLibraryService
        self.photoImportService = photoImportService
        self.ocrPipelineService = ocrPipelineService
        self.searchService = searchService
        self.embeddingPipelineService = embeddingPipelineService
    }

    /// Fire-and-forget: runs OCR on any pending photos, then chains embedding.
    /// Safe to call multiple times — no-ops if already running.
    func startBackgroundIndexing() {
        guard !isOCRRunning else { return }
        Task { await runOCRThenEmbed() }
    }

    /// Fire-and-forget: only runs embedding (used after share-extension saves, which skip OCR).
    func startEmbeddingIfNeeded() {
        guard !embeddingPipelineService.isRunning else { return }
        Task { await embeddingPipelineService.processQueue() }
    }

    private func runOCRThenEmbed() async {
        guard !isOCRRunning else { return }
        isOCRRunning = true
        var completed = 0

        await ocrPipelineService.processQueue(
            onStart: { [weak self] total in
                self?.ocrProgress = OCRProgress(completed: 0, total: total)
            },
            onProgress: { [weak self] _ in
                guard let self else { return }
                completed += 1
                self.ocrProgress = OCRProgress(
                    completed: completed,
                    total: self.ocrProgress?.total ?? completed
                )
            }
        )

        isOCRRunning = false
        ocrProgress = nil
        memoriesVersion += 1 // Refresh list with fresh OCR text

        // Chain: embed everything that completed OCR
        await embeddingPipelineService.processQueue()
        memoriesVersion += 1 // Refresh again so search picks up new embeddings
    }
}
