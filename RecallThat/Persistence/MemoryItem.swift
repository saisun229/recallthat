import Foundation
import SwiftData

/// SwiftData model that persists Memory data on device.
/// This is an implementation detail of the persistence layer — not used outside Persistence/.
/// All other layers work with the Memory struct via MemoryRepository.
@Model
final class MemoryItem {
    @Attribute(.unique) var id: UUID
    var sourceTypeRaw: String
    var photoAssetIdentifier: String?
    var localThumbnailPath: String?
    var createdAt: Date
    var importedAt: Date
    var title: String
    var ocrText: String
    var ocrStatusRaw: String
    var searchText: String
    var originalExists: Bool
    var deletedOriginalAt: Date?
    var sourceURL: String?

    init(
        id: UUID = UUID(),
        sourceTypeRaw: String = MemorySourceType.screenshot.rawValue,
        photoAssetIdentifier: String? = nil,
        localThumbnailPath: String? = nil,
        createdAt: Date = Date(),
        importedAt: Date = Date(),
        title: String = "",
        ocrText: String = "",
        ocrStatusRaw: String = OCRStatus.notStarted.rawValue,
        searchText: String = "",
        originalExists: Bool = true,
        deletedOriginalAt: Date? = nil,
        sourceURL: String? = nil
    ) {
        self.id = id
        self.sourceTypeRaw = sourceTypeRaw
        self.photoAssetIdentifier = photoAssetIdentifier
        self.localThumbnailPath = localThumbnailPath
        self.createdAt = createdAt
        self.importedAt = importedAt
        self.title = title
        self.ocrText = ocrText
        self.ocrStatusRaw = ocrStatusRaw
        self.searchText = searchText
        self.originalExists = originalExists
        self.deletedOriginalAt = deletedOriginalAt
        self.sourceURL = sourceURL
    }

    /// Convert to the domain model used by services and view models
    func toDomain() -> Memory {
        Memory(
            id: id,
            sourceType: MemorySourceType(rawValue: sourceTypeRaw) ?? .screenshot,
            photoAssetIdentifier: photoAssetIdentifier,
            localThumbnailPath: localThumbnailPath,
            createdAt: createdAt,
            importedAt: importedAt,
            title: title,
            ocrText: ocrText,
            ocrStatus: OCRStatus(rawValue: ocrStatusRaw) ?? .notStarted,
            searchText: searchText,
            originalExists: originalExists,
            deletedOriginalAt: deletedOriginalAt,
            sourceURL: sourceURL
        )
    }
}
