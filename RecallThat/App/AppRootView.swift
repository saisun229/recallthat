import SwiftUI
import SwiftData

private let onboardingKey = "hasCompletedOnboarding"

/// Bootstraps the dependency graph once the SwiftData ModelContext is available,
/// shows onboarding on first launch, then hands off to ContentView.
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var appEnvironment: AppEnvironment?
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: onboardingKey)

    var body: some View {
        ZStack {
            if let env = appEnvironment {
                ContentView()
                    .environment(env)
                    .fullScreenCover(isPresented: $showOnboarding) {
                        OnboardingView {
                            UserDefaults.standard.set(true, forKey: onboardingKey)
                            showOnboarding = false
                        }
                    }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let env = appEnvironment else { return }
            env.memoriesVersion += 1
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
