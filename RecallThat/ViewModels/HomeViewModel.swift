import Foundation
import Observation
import Photos

@Observable
final class HomeViewModel {
    var memories: [Memory] = []
    var isLoading: Bool = false
    var isImporting: Bool = false
    var errorMessage: String? = nil
    var permissionStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

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
}
