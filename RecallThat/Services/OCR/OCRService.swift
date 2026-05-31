import Foundation

/// Isolates Apple Vision OCR from the rest of the app.
/// Implemented in Phase 4. Stub only in Phase 0.
@MainActor
protocol OCRServiceProtocol {
    /// Extract text from a Photos asset by its localIdentifier.
    /// Returns the extracted text string, or throws on failure.
    func extractText(from photoAssetIdentifier: String) async throws -> String
}
