import Foundation
@preconcurrency import Photos

@MainActor
final class DefaultPhotoLibraryService: PhotoLibraryServiceProtocol {

    var authorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchScreenshotIdentifiers() async -> [String] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        #if targetEnvironment(simulator)
        // Simulator: photos added via drag-and-drop don't carry the .photoScreenshot
        // media subtype — import all images so the app is testable without a real device.
        #else
        options.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        #endif

        var identifiers: [String] = []
        let result = PHAsset.fetchAssets(with: .image, options: options)
        result.enumerateObjects { asset, _, _ in
            identifiers.append(asset.localIdentifier)
        }
        return identifiers
    }

    func deleteAsset(identifier: String) async throws {
        try await deleteAssets(identifiers: [identifier])
    }

    func deleteAssets(identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count > 0 else { return }
        // Single performChanges call = single system permission prompt regardless of count
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}
