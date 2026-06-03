import Foundation
import Observation

@Observable
final class HomeViewModel {
    var memories: [Memory] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil

    func load(from repository: any MemoryRepository) async {
        isLoading = true
        errorMessage = nil
        do {
            memories = try await repository.fetchAll()
        } catch {
            errorMessage = "Could not load memories."
        }
        isLoading = false
    }
}
