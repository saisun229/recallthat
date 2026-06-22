import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let isUser: Bool
    let content: String
    let timestamp: Date
    /// Memories referenced by this response, shown as tappable thumbnail cards instead of plain-text citations.
    let sources: [Memory]

    init(isUser: Bool, content: String, sources: [Memory] = []) {
        self.id = UUID()
        self.isUser = isUser
        self.content = content
        self.timestamp = Date()
        self.sources = sources
    }
}
