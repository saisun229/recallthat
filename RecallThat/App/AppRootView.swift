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
            appEnvironment = AppEnvironment(repository: repo)
        }
    }
}
