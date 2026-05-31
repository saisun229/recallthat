import Foundation

/// Isolates search logic from views and view models.
/// Implemented in Phase 5. Stub only in Phase 0.
@MainActor
protocol SearchServiceProtocol {
    /// Search memories by keyword. Case-insensitive, partial/contains matching.
    /// Searches the Memory.searchText field (denormalized title + ocrText).
    func search(query: String, in memories: [Memory]) -> [Memory]
}
