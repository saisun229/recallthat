import Foundation
import Observation

@Observable
final class SearchViewModel {
    var query: String = ""
    var results: [Memory] = []
    var isSearching: Bool = false
}
