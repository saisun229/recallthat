import Foundation
import Observation
@preconcurrency import Photos

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
        guard !isRunningOCR else { return }
        isRunningOCR = true
        var completed = 0

        await pipeline.processQueue(
            onStart: { [weak self] total in
                self?.ocrProgress = OCRProgress(completed: 0, total: total)
            },
            onProgress: { [weak self] _ in
                completed += 1
                if let total = self?.ocrProgress?.total {
                    self?.ocrProgress = OCRProgress(completed: completed, total: total)
                }
            }
        )

        memories = (try? await repository.fetchAll()) ?? memories
        ocrProgress = nil
        isRunningOCR = false
    }

    func resetFailedItems(in repository: any MemoryRepository) async {
        let failed = memories.filter { $0.ocrStatus == .failed && $0.photoAssetIdentifier != nil }
        guard !failed.isEmpty else { return }
        for var memory in failed {
            memory.ocrStatus = .notStarted
            try? await repository.update(memory)
        }
        await load(from: repository)
    }

    func retryFailedOCR(using pipeline: OCRPipelineService, repository: any MemoryRepository) async {
        await resetFailedItems(in: repository)
        await runOCR(using: pipeline, repository: repository)
    }

    func reindexAll(using pipeline: OCRPipelineService, repository: any MemoryRepository) async {
        for var memory in memories where memory.photoAssetIdentifier != nil {
            if memory.ocrStatus != .notStarted {
                memory.ocrStatus = .notStarted
                try? await repository.update(memory)
            }
        }
        await load(from: repository)
        await runOCR(using: pipeline, repository: repository)
    }

    // MARK: - Selection

    var isSelecting: Bool = false
    var selectedIDs: Set<UUID> = []

    func toggleSelecting() {
        isSelecting.toggle()
        if !isSelecting { selectedIDs.removeAll() }
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(memories.map(\.id))
    }

    // MARK: - Delete

    func safeDelete(
        _ memory: Memory,
        photoService: any PhotoLibraryServiceProtocol,
        repository: any MemoryRepository
    ) async {
        guard let identifier = memory.photoAssetIdentifier, memory.originalExists else { return }
        try? await photoService.deleteAsset(identifier: identifier)
        var updated = memory
        updated.originalExists = false
        updated.deletedOriginalAt = Date()
        try? await repository.update(updated)
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            memories[index].originalExists = false
            memories[index].deletedOriginalAt = Date()
        }
    }

    func safeDeleteSelected(
        photoService: any PhotoLibraryServiceProtocol,
        repository: any MemoryRepository
    ) async {
        let targets = memories.filter { selectedIDs.contains($0.id) && $0.originalExists }
        let identifiers = targets.compactMap(\.photoAssetIdentifier)

        // Delete all originals in one Photos request — single permission prompt
        try? await photoService.deleteAssets(identifiers: identifiers)

        let now = Date()
        for memory in targets {
            var updated = memory
            updated.originalExists = false
            updated.deletedOriginalAt = now
            try? await repository.update(updated)
            if let i = memories.firstIndex(where: { $0.id == memory.id }) {
                memories[i].originalExists = false
                memories[i].deletedOriginalAt = now
            }
        }
        selectedIDs.removeAll()
        isSelecting = false
    }

    func hardDeleteSelected(
        photoService: any PhotoLibraryServiceProtocol,
        repository: any MemoryRepository
    ) async {
        let targets = memories.filter { selectedIDs.contains($0.id) }
        for memory in targets {
            if memory.originalExists, let identifier = memory.photoAssetIdentifier {
                try? await photoService.deleteAsset(identifier: identifier)
            }
            try? await repository.delete(id: memory.id)
        }
        memories.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        isSelecting = false
    }
}
