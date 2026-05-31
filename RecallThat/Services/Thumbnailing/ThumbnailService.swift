import Foundation

/// Generates and caches small local thumbnails from Photos assets.
/// Implemented in Phase 6. Stub only in Phase 0.
@MainActor
protocol ThumbnailServiceProtocol {
    /// Request a thumbnail for a Photos asset localIdentifier.
    /// Returns a local file path to the saved thumbnail, or nil on failure.
    func thumbnail(for photoAssetIdentifier: String) async -> String?
}
