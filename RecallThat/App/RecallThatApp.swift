import SwiftUI
import SwiftData

@main
struct RecallThatApp: App {

    // Shared container so the Share Extension and main app read/write the same store.
    // Falls back to the default location in Simulator where App Groups are unavailable.
    private let container: ModelContainer = {
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.recallthat.app"
        ) {
            let storeURL = groupURL.appendingPathComponent("recallthat.sqlite")
            let config = ModelConfiguration(url: storeURL)
            if let c = try? ModelContainer(for: MemoryItem.self, configurations: config) {
                return c
            }
        }
        return try! ModelContainer(for: MemoryItem.self)
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(container)
        }
    }
}
