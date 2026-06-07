import Foundation

/// Isolates search logic from views and view models.
/// Implemented in Phase 5. Stub only in Phase 0.
@MainActor
protocol SearchServiceProtocol {
    /// Search memories by keyword (and optionally semantic embedding). Case-insensitive partial match.
    func search(query: String, in memories: [Memory]) async -> [Memory]
}
