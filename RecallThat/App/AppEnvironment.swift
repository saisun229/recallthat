import Foundation
import Observation

/// Holds app-wide dependencies. Injected via SwiftUI environment.
/// Created once in AppRootView after the SwiftData ModelContext is available.
@Observable
final class AppEnvironment {
    let memoryRepository: any MemoryRepository

    init(repository: any MemoryRepository) {
        self.memoryRepository = repository
    }
}
