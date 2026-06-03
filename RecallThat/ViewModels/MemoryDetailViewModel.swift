import Foundation
import Observation

@MainActor
@Observable
final class MemoryDetailViewModel {
    var memory: Memory
    var showDeleteConfirmation: Bool = false
    var isDeleting: Bool = false
    var deleteError: String? = nil

    init(memory: Memory) {
        self.memory = memory
    }

    func deleteOriginal(
        photoService: any PhotoLibraryServiceProtocol,
        repository: any MemoryRepository
    ) async {
        guard let identifier = memory.photoAssetIdentifier, memory.originalExists else { return }
        isDeleting = true
        deleteError = nil
        do {
            try await photoService.deleteAsset(identifier: identifier)
            memory.originalExists = false
            memory.deletedOriginalAt = Date()
            try await repository.update(memory)
        } catch {
            deleteError = "Could not delete the original screenshot. Please try again."
        }
        isDeleting = false
    }
}
