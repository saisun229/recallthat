import SwiftUI
@preconcurrency import Photos

/// Loads and displays a small thumbnail for a Photos asset identifier.
/// Shows a placeholder while loading or if the asset is unavailable.
struct AssetThumbnailView: View {
    let identifier: String
    var size: CGFloat = 56

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task(id: identifier) {
            image = await loadThumbnail()
        }
    }

    private func loadThumbnail() async -> UIImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let targetSize = CGSize(width: size * 2, height: size * 2)

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true

            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { img, info in
                guard !resumed else { return }
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                if isDegraded { return }
                resumed = true
                continuation.resume(returning: img)
            }
        }
    }
}
