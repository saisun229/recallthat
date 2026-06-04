import Foundation
import Observation
import Photos

@MainActor
@Observable
final class HomeViewModel {
    var memories: [Memory] = []
    var isLoading: Bool = false
    var isImporting: Bool = false
    var isRunningOCR: Bool = false
    var ocrProgress: OCRProgress? = nil
    var errorMessage: String? = nil
    var permissionStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    struct OCRProgress {
        let completed: Int
        let total: Int
        var description: String { "Indexing \(completed) of \(total)…" }
    }

    func load(from repository: any MemoryRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            memories = try await repository.fetchAll()
        } catch {
            errorMessage = "Could not load memories."
        }
        isLoading = false
    }

    func requestPhotoAccess(using service: any PhotoLibraryServiceProtocol) async {
        permissionStatus = await service.requestAuthorization()
    }

    func importScreenshots(
        using importService: PhotoImportService,
        repository: any MemoryRepository
    ) async {
        isImporting = true
        do {
            let count = try await importService.importNewScreenshots()
            if count > 0 {
                await load(from: repository)
            }
        } catch {
            errorMessage = "Import failed. Please try again."
        }
        isImporting = false
    }

    func runOCR(using pipeline: OCRPipelineService, repository: any MemoryRepository) async {
        let pending = memories.filter { $0.ocrStatus == .notStarted && $0.photoAssetIdentifier != nil }
        guard !pending.isEmpty else { return }

        isRunningOCR = true
        var completed = 0
        ocrProgress = OCRProgress(completed: 0, total: pending.count)

        // processQueue is @MainActor so the callback runs on the main actor —
        // safe to mutate @MainActor ViewModel properties directly, no Task needed.
        await pipeline.processQueue { [weak self] _ in
            completed += 1
            self?.ocrProgress = OCRProgress(completed: completed, total: pending.count)
        }

        // Reload the full list once all OCR is done
        memories = (try? await repository.fetchAll()) ?? memories
        ocrProgress = nil
        isRunningOCR = false
    }

    func retryFailedOCR(using pipeline: OCRPipelineService, repository: any MemoryRepository) async {
        // Re-queue failed items by resetting their status, then run the pipeline
        let failed = memories.filter { $0.ocrStatus == .failed && $0.photoAssetIdentifier != nil }
        guard !failed.isEmpty else { return }
        for var memory in failed {
            memory.ocrStatus = .notStarted
            try? await repository.update(memory)
        }
        await load(from: repository)
        await runOCR(using: pipeline, repository: repository)
    }
}
