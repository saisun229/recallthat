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

    func startNewConversation() {
        messages = []
        inputText = ""
        limitError = nil
        openAIError = nil
    }

    func send(using searchService: any SearchServiceProtocol, repository: any MemoryRepository) async {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isResponding else { return }

        guard ChatQueryCounter.hasQueriesRemaining else {
            limitError = "You've used today's \(ChatQueryCounter.limitPerDay) AI queries. Resets tomorrow."
            return
        }

        messages.append(ChatMessage(isUser: true, content: text))
        inputText = ""
        isResponding = true
        limitError = nil

        let allMemories = (try? await repository.fetchAll()) ?? []
        let relevant = await searchService.search(query: text, in: allMemories)

        let response: String
        let sources: [Memory]
        if relevant.isEmpty {
            response = "No matches found in your \(allMemories.count) saved memories for that query. Try different keywords, or turn on AI sharing in Settings to enable semantic search."
            sources = []
        } else if APIConfig.aiFeaturesEnabled {
            response = await queryOpenAI(query: text, relevant: relevant)
            sources = Array(relevant.prefix(10))
        } else {
            // AI sharing off (no key, or no consent) — the tappable source cards below show titles/thumbnails
            response = "Found \(relevant.count) related \(relevant.count == 1 ? "memory" : "memories"). Turn on AI sharing in Settings for AI-generated answers with full citations."
            sources = Array(relevant.prefix(10))
        }

        messages.append(ChatMessage(isUser: false, content: response, sources: sources))
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
