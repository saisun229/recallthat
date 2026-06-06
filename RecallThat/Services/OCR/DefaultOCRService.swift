import Foundation
@preconcurrency import Vision
@preconcurrency import Photos
import UIKit

enum OCRError: Error, LocalizedError {
    case assetNotFound
    case imageLoadFailed

    var errorDescription: String? {
        switch self {
        case .assetNotFound:   return "The original screenshot could not be found in Photos."
        case .imageLoadFailed: return "The screenshot image could not be loaded."
        }
    }
}

@MainActor
final class DefaultOCRService: OCRServiceProtocol {

    func extractText(from photoAssetIdentifier: String) async throws -> String {
        let image = try await loadImage(for: photoAssetIdentifier)
        return try await recognizeText(in: image)
    }

    // MARK: - Private

    private func loadImage(for identifier: String) async throws -> UIImage {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { throw OCRError.assetNotFound }

        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, info in
                let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool ?? false
                if isDegraded { return }
                guard !resumed else { return }
                resumed = true
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: OCRError.imageLoadFailed)
                }
            }
        }
    }

    // Runs VNRecognizeTextRequest on a background thread to keep UI responsive
    private func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRError.imageLoadFailed }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            return observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}
