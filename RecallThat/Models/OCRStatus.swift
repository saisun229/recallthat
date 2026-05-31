import Foundation

/// Lifecycle of OCR text extraction for a memory item.
enum OCRStatus: String, Codable {
    case notStarted
    case pending
    case complete
    case failed

    var label: String {
        switch self {
        case .notStarted: return "Not indexed"
        case .pending:    return "Processing"
        case .complete:   return "Indexed"
        case .failed:     return "Failed"
        }
    }
}
