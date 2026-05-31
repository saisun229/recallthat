import SwiftUI
import SwiftData

@main
struct RecallThatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: MemoryItem.self)
        }
    }
}
