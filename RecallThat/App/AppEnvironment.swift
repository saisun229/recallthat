import Foundation
import Observation

/// Holds app-wide dependencies. Injected via SwiftUI environment.
/// Created once in AppRootView after the SwiftData ModelContext is available.
@Observable
final class AppEnvironment {
    let memoryRepository: any MemoryRepository
    let photoLibraryService: any PhotoLibraryServiceProtocol
    let photoImportService: PhotoImportService

    init(
        repository: any MemoryRepository,
        photoLibraryService: any PhotoLibraryServiceProtocol,
        photoImportService: PhotoImportService
    ) {
        self.memoryRepository = repository
        self.photoLibraryService = photoLibraryService
        self.photoImportService = photoImportService
    }
}
