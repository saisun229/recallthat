import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isResponding: Bool = false
    var limitError: String? = nil

    func send(using searchService: any SearchServiceProtocol, repository: any MemoryRepository) async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isResponding else { return }

        guard ChatQueryCounter.hasQueriesRemaining else {
            limitError = "You've used all 30 AI queries for this month. Resets on the 1st."
            return
        }

        messages.append(ChatMessage(isUser: true, content: text))
        inputText = ""
        isResponding = true
        limitError = nil

        let allMemories = (try? await repository.fetchAll()) ?? []
        let relevant = await searchService.search(query: text, in: allMemories)

        let response: String
        if relevant.isEmpty {
            response = "I didn't find anything in your memories about that. Try saving more screenshots first!"
        } else if APIConfig.hasOpenAIKey {
            let llm = OpenAILLMService(apiKey: APIConfig.openAIKey)
            response = (try? await llm.answer(query: text, context: relevant))
                ?? "I found \(relevant.count) related memor\(relevant.count == 1 ? "y" : "ies") but couldn't summarize them right now."
        } else {
            let titles = relevant.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
            response = "Found \(relevant.count) related memor\(relevant.count == 1 ? "y" : "ies"):\n\(titles)"
        }

        messages.append(ChatMessage(isUser: false, content: response))
        ChatQueryCounter.recordQuery()
        isResponding = false
    }
}
