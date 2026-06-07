import Foundation
import Observation

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isResponding: Bool = false
    var limitError: String? = nil

    /// Non-nil when the last OpenAI call failed; shown as a banner so the user knows AI is unavailable.
    private(set) var openAIError: String? = nil

    func dismissOpenAIError() { openAIError = nil }

    func send(using searchService: any SearchServiceProtocol, repository: any MemoryRepository) async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isResponding else { return }

        guard ChatQueryCounter.hasQueriesRemaining else {
            limitError = "You've used today's 3 AI queries. Resets tomorrow."
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
            response = await queryOpenAI(query: text, relevant: relevant)
        } else {
            let titles = relevant.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
            response = "Found \(relevant.count) related \(relevant.count == 1 ? "memory" : "memories"):\n\(titles)"
        }

        messages.append(ChatMessage(isUser: false, content: response))
        ChatQueryCounter.recordQuery()
        isResponding = false
    }

    // MARK: - Private

    private func queryOpenAI(query: String, relevant: [Memory]) async -> String {
        let llm = OpenAILLMService(apiKey: APIConfig.openAIKey)
        let count = relevant.count
        let noun = count == 1 ? "memory" : "memories"
        do {
            let answer = try await llm.answer(query: query, context: relevant)
            openAIError = nil
            return answer
        } catch EmbeddingError.networkError {
            openAIError = "No internet — AI unavailable. Retry when connected."
            return "Found \(count) related \(noun), but couldn't reach AI. Check your connection and try again."
        } catch EmbeddingError.rateLimited {
            openAIError = "OpenAI rate limit hit. Try again in a minute."
            return "Found \(count) related \(noun), but hit the OpenAI rate limit. Try again shortly."
        } catch EmbeddingError.apiKeyMissing {
            openAIError = "API key invalid or missing. Check your OpenAI key."
            return "OpenAI API key issue. Found \(count) related \(noun)."
        } catch EmbeddingError.apiError(let msg) {
            openAIError = "AI error: \(msg)"
            return "Found \(count) related \(noun), but AI is temporarily unavailable."
        } catch {
            openAIError = "Unexpected error: \(error.localizedDescription)"
            return "Found \(count) related \(noun) but couldn't summarize them right now."
        }
    }
}
