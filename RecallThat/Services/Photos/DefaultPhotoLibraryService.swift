import Foundation
import Photos

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
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset] as NSArray)
        }
    }
}
