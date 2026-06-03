import SwiftUI
import SwiftData

@main
struct RecallThatApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
                .modelContainer(for: MemoryItem.self)
        }
    }
}
