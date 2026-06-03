import SwiftUI
import SwiftData

/// Bootstraps the dependency graph once the SwiftData ModelContext is available,
/// then hands off to ContentView with the environment wired up.
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appEnvironment: AppEnvironment?

    var body: some View {
        ZStack {
            if let env = appEnvironment {
                ContentView()
                    .environment(env)
            }
        }
        .onAppear {
            guard appEnvironment == nil else { return }
            let repo = SwiftDataMemoryRepository(context: modelContext)
            try? repo.seedMockDataIfNeeded()
            let photoService = DefaultPhotoLibraryService()
            let importService = PhotoImportService(photoLibrary: photoService, repository: repo)
            let ocrService = DefaultOCRService()
            let ocrPipeline = OCRPipelineService(ocrService: ocrService, repository: repo)
            let searchService = DefaultSearchService()
            appEnvironment = AppEnvironment(
                repository: repo,
                photoLibraryService: photoService,
                photoImportService: importService,
                ocrPipelineService: ocrPipeline,
                searchService: searchService
            )
        }
    }
}
