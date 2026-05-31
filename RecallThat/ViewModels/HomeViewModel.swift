import Foundation
import Observation

@Observable
final class HomeViewModel {
    var memories: [Memory] = []
    var isLoading: Bool = false
    var errorMessage: String? = nil
}
