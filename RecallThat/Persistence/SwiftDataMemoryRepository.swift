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
            deletedOriginalAt: memory.deletedOriginalAt,
            sourceURL: memory.sourceURL,
            embeddingStatusRaw: memory.embeddingStatus.rawValue,
            embeddingData: memory.embedding.map(MemoryItem.floatsToData)
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
        item.sourceURL = memory.sourceURL
        item.embeddingStatusRaw = memory.embeddingStatus.rawValue
        item.embeddingData = memory.embedding.map(MemoryItem.floatsToData)
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

    // No-op: mock seed removed — real device testing uses actual Photos library
    func seedMockDataIfNeeded() throws {}
}
