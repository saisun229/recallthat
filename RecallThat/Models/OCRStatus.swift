import Foundation

/// Lifecycle of OCR text extraction for a memory item.
enum OCRStatus: String, Codable {
    case notStarted
    case pending
    case complete
    case failed
}
