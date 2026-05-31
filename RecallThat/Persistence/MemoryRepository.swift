import Foundation

/// Abstract interface for reading and writing Memory items.
/// The SwiftData implementation (SwiftDataMemoryRepository) is added in Phase 2.
/// Views and services always talk to this protocol — never to SwiftData directly.
@MainActor
protocol MemoryRepository {
    func fetchAll() async throws -> [Memory]
    func fetch(by id: UUID) async throws -> Memory?
    func save(_ memory: Memory) async throws
    func update(_ memory: Memory) async throws
    func delete(id: UUID) async throws
}
