import Foundation
import Observation
@preconcurrency import Photos

@MainActor
@Observable
final class HomeViewModel {
    var memories: [Memory] = []
    var isLoading: Bool = false
    var isImporting: Bool = false
    var errorMessage: String? = nil
    var permissionStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    // MARK: - Debug entries (from failed share extension saves)

    private(set) var debugEntries: [Memory] = []

    var debugEntryIDs: Set<UUID> { Set(debugEntries.map(\.id)) }

    func loadDebugEntries() {
        let defaults = UserDefaults(suiteName: "group.com.recallthat.app")
        guard let raw = defaults?.array(forKey: "shareDebugEntries") as? [[String: String]] else {
            debugEntries = []
            return
        }
        debugEntries = raw.compactMap { dict in
            guard let idStr = dict["id"], let id = UUID(uuidString: idStr),
                  let tsStr = dict["ts"], let ts = Double(tsStr) else { return nil }
            let date = Date(timeIntervalSince1970: ts)
            let reason   = dict["why"]   ?? "Unknown error"
            let types    = dict["types"] ?? ""
            let url      = dict["url"]?.isEmpty == false ? dict["url"] : nil
            let title    = dict["title"]?.isEmpty == false ? dict["title"] : nil

            let debugText = [
                "Failure: \(reason)",
                types.isEmpty   ? nil : "Types detected: \(types)",
                url.map        { "URL: \($0)" },
                title.map      { "Title attempted: \($0)" },
                "Time: \(date.formatted())"
            ].compactMap { $0 }.joined(separator: "\n")

            return Memory(
                id: id,
                sourceType: .sharedText,
                photoAssetIdentifier: nil,
                localThumbnailPath: nil,
                createdAt: date,
                importedAt: date,
                title: "Share Failed — \(reason)",
                ocrText: debugText,
                ocrStatus: .failed,
                searchText: debugText.lowercased(),
                originalExists: false,
                deletedOriginalAt: nil,
                sourceURL: url,
                embedding: nil,
                embeddingStatus: .notStarted
            )
        }
    }

    func clearDebugEntry(id: UUID) {
        let defaults = UserDefaults(suiteName: "group.com.recallthat.app")
        var entries = (defaults?.array(forKey: "shareDebugEntries") as? [[String: String]]) ?? []
        entries.removeAll { $0["id"] == id.uuidString }
        defaults?.set(entries, forKey: "shareDebugEntries")
        debugEntries.removeAll { $0.id == id }
    }

    // MARK: - Temporal grouping

    var groupedMemories: [(label: String, memories: [Memory])] {
        var groups: [(label: String, memories: [Memory])] = []

        if !debugEntries.isEmpty {
            groups.append((label: "Share Failures", memories: debugEntries))
        }

        let now = Date()
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let twentyOneDaysAgo = calendar.date(byAdding: .day, value: -21, to: now)!

        var last7: [Memory] = []
        var prev2Weeks: [Memory] = []
        var byYear: [Int: [Memory]] = [:]

        for memory in memories {
            if memory.createdAt >= sevenDaysAgo {
                last7.append(memory)
            } else if memory.createdAt >= twentyOneDaysAgo {
                prev2Weeks.append(memory)
            } else {
                let year = calendar.component(.year, from: memory.createdAt)
                byYear[year, default: []].append(memory)
            }
        }

        if !last7.isEmpty { groups.append((label: "Last 7 Days", memories: last7)) }
        if !prev2Weeks.isEmpty { groups.append((label: "Previous 2 Weeks", memories: prev2Weeks)) }
        for year in byYear.keys.sorted(by: >) {
            if let g = byYear[year], !g.isEmpty {
                groups.append((label: "\(year)", memories: g))
            }
        }
        return groups
    }

    func load(from repository: any MemoryRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            memories = try await repository.fetchAll()
        } catch {
            errorMessage = "Could not load memories."
        }
        loadDebugEntries()
        isLoading = false
    }

    func loadQuietly(from repository: any MemoryRepository) async {
        memories = (try? await repository.fetchAll()) ?? memories
        loadDebugEntries()
    }

    func requestPhotoAccess(using service: any PhotoLibraryServiceProtocol) async {
        permissionStatus = await service.requestAuthorization()
    }

    func importScreenshots(
        using importService: PhotoImportService,
        repository: any MemoryRepository
    ) async {
        isImporting = true
        do {
            let count = try await importService.importNewScreenshots()
            if count > 0 {
                await load(from: repository)
            }
        } catch {
            errorMessage = "Import failed. Please try again."
        }
        isImporting = false
    }

    /// Reset OCR-failed photo memories back to notStarted so the pipeline retries them.
    func resetFailedItems(in repository: any MemoryRepository) async {
        let failed = memories.filter { $0.ocrStatus == .failed && $0.photoAssetIdentifier != nil }
        guard !failed.isEmpty else { return }
        for var memory in failed {
            memory.ocrStatus = .notStarted
            try? await repository.update(memory)
        }
        await load(from: repository)
    }

    /// Reset ALL photo memories to notStarted for a full re-index (also clears embeddings).
    func reindexAll(in repository: any MemoryRepository) async {
        for var memory in memories where memory.photoAssetIdentifier != nil {
            var needsUpdate = false
            if memory.ocrStatus != .notStarted {
                memory.ocrStatus = .notStarted
                needsUpdate = true
            }
            if memory.embeddingStatus != .notStarted {
                memory.embeddingStatus = .notStarted
                memory.embedding = nil
                needsUpdate = true
            }
            if needsUpdate {
                try? await repository.update(memory)
            }
        }
        await load(from: repository)
    }

    // MARK: - Selection

    var isSelecting: Bool = false
    var selectedIDs: Set<UUID> = []

    func toggleSelecting() {
        isSelecting.toggle()
        if !isSelecting { selectedIDs.removeAll() }
    }

    func toggleSelection(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    func selectAll() {
        selectedIDs = Set(memories.map(\.id))
    }

    // MARK: - Delete

    func safeDelete(
        _ memory: Memory,
        photoService: any PhotoLibraryServiceProtocol,
        repository: any MemoryRepository
    ) async {
        guard let identifier = memory.photoAssetIdentifier, memory.originalExists else { return }
        try? await photoService.deleteAsset(identifier: identifier)
        var updated = memory
        updated.originalExists = false
        updated.deletedOriginalAt = Date()
        try? await repository.update(updated)
        if let index = memories.firstIndex(where: { $0.id == memory.id }) {
            memories[index].originalExists = false
            memories[index].deletedOriginalAt = Date()
        }
    }

    func safeDeleteSelected(
        photoService: any PhotoLibraryServiceProtocol,
        repository: any MemoryRepository
    ) async {
        let targets = memories.filter { selectedIDs.contains($0.id) && $0.originalExists }
        let identifiers = targets.compactMap(\.photoAssetIdentifier)

        try? await photoService.deleteAssets(identifiers: identifiers)

        let now = Date()
        for memory in targets {
            var updated = memory
            updated.originalExists = false
            updated.deletedOriginalAt = now
            try? await repository.update(updated)
            if let i = memories.firstIndex(where: { $0.id == memory.id }) {
                memories[i].originalExists = false
                memories[i].deletedOriginalAt = now
            }
        }
        selectedIDs.removeAll()
        isSelecting = false
    }

    func hardDeleteSelected(
        photoService: any PhotoLibraryServiceProtocol,
        repository: any MemoryRepository
    ) async {
        let targets = memories.filter { selectedIDs.contains($0.id) }
        for memory in targets {
            if memory.originalExists, let identifier = memory.photoAssetIdentifier {
                try? await photoService.deleteAsset(identifier: identifier)
            }
            try? await repository.delete(id: memory.id)
        }
        memories.removeAll { selectedIDs.contains($0.id) }
        selectedIDs.removeAll()
        isSelecting = false
    }
}
