import Foundation

/// Core domain model representing a single indexed memory (screenshot or future type).
/// All services and view models use this struct — they never touch SwiftData directly.
struct Memory: Identifiable, Equatable {
    let id: UUID
    let sourceType: MemorySourceType

    /// PHAsset localIdentifier — nil if the item did not come from Photos
    let photoAssetIdentifier: String?

    /// Path to a small local thumbnail written by ThumbnailService (Phase 6)
    var localThumbnailPath: String?

    /// When the original screenshot was captured (from PHAsset.creationDate)
    let createdAt: Date

    /// When RecallThat first indexed this memory
    let importedAt: Date

    /// Human-readable title: first meaningful OCR line, or "Screenshot from [date]"
    var title: String

    /// Full OCR text extracted by OCRService
    var ocrText: String

    var ocrStatus: OCRStatus

    /// Denormalized search index: title + ocrText, lowercased (for fast local search)
    var searchText: String

    /// True while the original Photos asset still exists in the library
    var originalExists: Bool

    /// Set when the user explicitly deletes the original via the Phase 7 flow
    var deletedOriginalAt: Date?

    /// Original URL for sharedURL memories (nil for screenshot/sharedImage/sharedText)
    var sourceURL: String?
}
