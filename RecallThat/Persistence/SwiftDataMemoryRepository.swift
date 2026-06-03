import Foundation
import SwiftData

@MainActor
final class SwiftDataMemoryRepository: MemoryRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchAll() async throws -> [Memory] {
        let descriptor = FetchDescriptor<MemoryItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map { $0.toDomain() }
    }

    func fetch(by id: UUID) async throws -> Memory? {
        let descriptor = FetchDescriptor<MemoryItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first?.toDomain()
    }

    func save(_ memory: Memory) async throws {
        let item = MemoryItem(
            id: memory.id,
            sourceTypeRaw: memory.sourceType.rawValue,
            photoAssetIdentifier: memory.photoAssetIdentifier,
            localThumbnailPath: memory.localThumbnailPath,
            createdAt: memory.createdAt,
            importedAt: memory.importedAt,
            title: memory.title,
            ocrText: memory.ocrText,
            ocrStatusRaw: memory.ocrStatus.rawValue,
            searchText: memory.searchText,
            originalExists: memory.originalExists,
            deletedOriginalAt: memory.deletedOriginalAt
        )
        context.insert(item)
        try context.save()
    }

    func update(_ memory: Memory) async throws {
        let id = memory.id
        let descriptor = FetchDescriptor<MemoryItem>(
            predicate: #Predicate { $0.id == id }
        )
        guard let item = try context.fetch(descriptor).first else { return }
        item.title = memory.title
        item.ocrText = memory.ocrText
        item.ocrStatusRaw = memory.ocrStatus.rawValue
        item.searchText = memory.searchText
        item.originalExists = memory.originalExists
        item.deletedOriginalAt = memory.deletedOriginalAt
        item.localThumbnailPath = memory.localThumbnailPath
        try context.save()
    }

    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<MemoryItem>(
            predicate: #Predicate { $0.id == id }
        )
        guard let item = try context.fetch(descriptor).first else { return }
        context.delete(item)
        try context.save()
    }

    // Inserts a few realistic mock items on first launch (DEBUG builds only)
    func seedMockDataIfNeeded() throws {
        #if DEBUG
        let count = try context.fetchCount(FetchDescriptor<MemoryItem>())
        guard count == 0 else { return }

        let mocks: [MemoryItem] = [
            MemoryItem(
                createdAt: Date().addingTimeInterval(-86_400 * 3),
                importedAt: Date().addingTimeInterval(-86_400 * 3),
                title: "WiFi password",
                ocrText: "Network: HomeNetwork_5G\nPassword: correct-horse-battery",
                ocrStatusRaw: OCRStatus.complete.rawValue,
                searchText: "wifi password network homenetwork_5g correct-horse-battery",
                originalExists: true
            ),
            MemoryItem(
                createdAt: Date().addingTimeInterval(-86_400 * 7),
                importedAt: Date().addingTimeInterval(-86_400 * 7),
                title: "Flight confirmation",
                ocrText: "Flight AA 1234\nDeparture: 09:45 AM\nGate: B22\nSeat: 14A",
                ocrStatusRaw: OCRStatus.complete.rawValue,
                searchText: "flight aa 1234 departure 09:45 gate b22 seat 14a confirmation",
                originalExists: false,
                deletedOriginalAt: Date().addingTimeInterval(-86_400 * 5)
            ),
            MemoryItem(
                createdAt: Date().addingTimeInterval(-3_600),
                importedAt: Date().addingTimeInterval(-3_600),
                title: "New screenshot",
                ocrText: "",
                ocrStatusRaw: OCRStatus.notStarted.rawValue,
                searchText: "",
                originalExists: true
            ),
        ]
        mocks.forEach { context.insert($0) }
        try context.save()
        #endif
    }
}
