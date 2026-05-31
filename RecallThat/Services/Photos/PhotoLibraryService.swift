import Foundation
import Photos

/// Isolates all PhotoKit access from the rest of the app.
/// Implemented in Phase 3. Stub only in Phase 0.
@MainActor
protocol PhotoLibraryServiceProtocol {
    /// Current Photos authorization status
    var authorizationStatus: PHAuthorizationStatus { get }

    /// Request Photos access. Returns the granted status.
    func requestAuthorization() async -> PHAuthorizationStatus

    /// Fetch localIdentifiers for all screenshot assets in the library.
    /// Does not load image data — callers use identifiers with ThumbnailService or OCRService.
    func fetchScreenshotIdentifiers() async -> [String]
}
