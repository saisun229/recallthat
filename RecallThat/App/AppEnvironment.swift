import Foundation
import Observation

/// Holds app-wide dependencies. Injected via SwiftUI environment.
/// Created once in AppRootView after the SwiftData ModelContext is available.
@Observable
final class AppEnvironment {
    let memoryRepository: any MemoryRepository
    let photoLibraryService: any PhotoLibraryServiceProtocol
    let photoImportService: PhotoImportService
    let ocrPipelineService: OCRPipelineService
    let searchService: any SearchServiceProtocol

    /// Incremented whenever memories are bulk-modified (e.g. Delete All in Settings)
    /// so views that hold their own copy can react and re-fetch.
    var memoriesVersion: Int = 0

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
