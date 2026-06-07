import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let isUser: Bool
    let content: String
    let timestamp: Date

    init(isUser: Bool, content: String) {
        self.id = UUID()
        self.isUser = isUser
        self.content = content
        self.timestamp = Date()
    }
}
