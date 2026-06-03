import Foundation
import Photos

/// Finds new screenshots in the Photos library and saves them as Memory records.
/// Handles deduplication — already-imported asset identifiers are skipped.
@MainActor
final class PhotoImportService {
    private let photoLibrary: any PhotoLibraryServiceProtocol
    private let repository: any MemoryRepository

    init(photoLibrary: any PhotoLibraryServiceProtocol, repository: any MemoryRepository) {
        self.photoLibrary = photoLibrary
        self.repository = repository
    }

    /// Returns the count of newly imported screenshots.
    func importNewScreenshots() async throws -> Int {
        let identifiers = await photoLibrary.fetchScreenshotIdentifiers()
        guard !identifiers.isEmpty else { return 0 }

        let existing = try await repository.fetchAll()
        let existingIdentifiers = Set(existing.compactMap(\.photoAssetIdentifier))
        let newIdentifiers = identifiers.filter { !existingIdentifiers.contains($0) }
        guard !newIdentifiers.isEmpty else { return 0 }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: newIdentifiers, options: nil)
        var assetsByIdentifier: [String: PHAsset] = [:]
        fetchResult.enumerateObjects { asset, _, _ in
            assetsByIdentifier[asset.localIdentifier] = asset
        }

        for identifier in newIdentifiers {
            let asset = assetsByIdentifier[identifier]
            let memory = Memory(
                id: UUID(),
                sourceType: .screenshot,
                photoAssetIdentifier: identifier,
                localThumbnailPath: nil,
                createdAt: asset?.creationDate ?? Date(),
                importedAt: Date(),
                title: "",
                ocrText: "",
                ocrStatus: .notStarted,
                searchText: "",
                originalExists: true,
                deletedOriginalAt: nil
            )
            try await repository.save(memory)
        }

        return newIdentifiers.count
    }
}
