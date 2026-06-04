import Foundation
import Observation

/// Holds app-wide dependencies. Injected via SwiftUI environment.
/// Created once in AppRootView after the SwiftData ModelContext is available.
@MainActor
@Observable
final class AppEnvironment {
    let memoryRepository: any MemoryRepository
    let photoLibraryService: any PhotoLibraryServiceProtocol
    let photoImportService: PhotoImportService
    let ocrPipelineService: OCRPipelineService
    let searchService: any SearchServiceProtocol

    init(
        repository: any MemoryRepository,
        photoLibraryService: any PhotoLibraryServiceProtocol,
        photoImportService: PhotoImportService,
        ocrPipelineService: OCRPipelineService,
        searchService: any SearchServiceProtocol
    ) {
        self.memoryRepository = repository
        self.photoLibraryService = photoLibraryService
        self.photoImportService = photoImportService
        self.ocrPipelineService = ocrPipelineService
        self.searchService = searchService
    }
}
