import Foundation
import UIKit

/// Processes the queue of memories waiting for OCR.
/// Works through notStarted memories one at a time, updating status and text in the repository.
@MainActor
final class OCRPipelineService {
    private let ocrService: any OCRServiceProtocol
    private let repository: any MemoryRepository

    init(ocrService: any OCRServiceProtocol, repository: any MemoryRepository) {
        self.ocrService = ocrService
        self.repository = repository
    }

    /// Processes all memories with ocrStatus == .notStarted that have a photo asset.
    /// Calls onStart with the total count, then onProgress after each item.
    func processQueue(onStart: ((Int) -> Void)? = nil, onProgress: ((UUID) -> Void)? = nil) async {
        guard let memories = try? await repository.fetchAll() else { return }
        let queue = memories.filter {
            $0.ocrStatus == .notStarted && $0.photoAssetIdentifier != nil
        }
        guard !queue.isEmpty else { return }

        // Keep running for ~30 s after the app backgrounds so the queue doesn't stall mid-batch.
        var bgTask = UIBackgroundTaskIdentifier.invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "RecallThat.OCR") {
            UIApplication.shared.endBackgroundTask(bgTask)
        }
        defer { UIApplication.shared.endBackgroundTask(bgTask) }

        onStart?(queue.count)
        for memory in queue {
            await processOne(memory: memory)
            onProgress?(memory.id)
        }
    }

    // MARK: - Private

    private func processOne(memory: Memory) async {
        guard let identifier = memory.photoAssetIdentifier else { return }

        var updated = memory
        updated.ocrStatus = .pending
        try? await repository.update(updated)

        do {
            let text = try await ocrService.extractText(from: identifier)
            updated.ocrText = text
            updated.ocrStatus = .complete
            if updated.title.isEmpty {
                updated.title = Self.firstMeaningfulLine(from: text)
            }
            updated.searchText = Self.buildSearchText(title: updated.title, ocrText: text)
        } catch {
            updated.ocrStatus = .failed
        }

        try? await repository.update(updated)
    }

    // MARK: - Helpers

    static func firstMeaningfulLine(from text: String) -> String {
        let line = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.count >= 3 } ?? ""
        return String(line.prefix(60))
    }

    static func buildSearchText(title: String, ocrText: String) -> String {
        "\(title) \(ocrText)".lowercased()
    }
}
