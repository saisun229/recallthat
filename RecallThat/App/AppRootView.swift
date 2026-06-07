import SwiftUI
import SwiftData
import CoreData

private let onboardingKey = "hasCompletedOnboarding"

/// Bootstraps the dependency graph once the SwiftData ModelContext is available,
/// shows onboarding on first launch, then hands off to ContentView.
struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var appEnvironment: AppEnvironment?
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: onboardingKey)
    @State private var lastSeenShareSave: Double = 0

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

            // Always bump version on foreground so stale views refresh
            env.memoriesVersion += 1

            // Check for new share-extension saves
            let shareSaveTime = UserDefaults(suiteName: "group.com.recallthat.app")?.double(forKey: "lastShareSave") ?? 0
            if shareSaveTime > lastSeenShareSave {
                lastSeenShareSave = shareSaveTime
                // Extra bump so HomeView / SearchView always pick up the new item
                env.memoriesVersion += 1
                // Share extension saves with ocrStatus=.complete; just run embedding
                env.startEmbeddingIfNeeded()
            }
        }
        // Cross-process SwiftData write from the Share Extension
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            guard let env = appEnvironment else { return }
            // Small delay to let the WAL checkpoint complete before re-fetching
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                env.memoriesVersion += 1
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
            let searchService = HybridSearchService()
            let embeddingPipeline = EmbeddingPipelineService(repository: repo)
            appEnvironment = AppEnvironment(
                repository: repo,
                photoLibraryService: photoService,
                photoImportService: importService,
                ocrPipelineService: ocrPipeline,
                searchService: searchService,
                embeddingPipelineService: embeddingPipeline
            )
        }
    }
}
