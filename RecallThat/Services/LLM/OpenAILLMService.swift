import Foundation

final class OpenAILLMService: LLMService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func answer(query: String, context: [Memory]) async throws -> String {
        let top = Array(context.prefix(10))
        let contextText = top.enumerated().map { i, m in
            let snippet = m.ocrText.isEmpty ? m.title : String(m.ocrText.prefix(600))
            let dateStr = Self.formatDate(m.createdAt)
            return "[\(i + 1)] \(m.title) (saved \(dateStr))\n\(snippet)"
        }.joined(separator: "\n\n---\n\n")

        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": """
                You are a personal memory assistant. The user has saved screenshots of things they want to remember, and you've been given the most relevant retrieved snippets from their library.

                Rules:
                - Answer using ONLY the provided memory snippets — never invent or assume facts not present
                - Be detailed and specific: include names, numbers, prices, dates, places, and key facts from the memories
                - Cite each source inline with [1], [2], etc. at the end of the sentence that uses it
                - Do NOT add a "Sources:" list at the end — the app renders the cited memories as tappable cards itself
                - If the memories only partially answer the question, explain what you found and what might be missing
                - Write in clear paragraphs; use a short bullet list only if multiple distinct items are being compared
                - Do not say "I" — address the user directly
                """
            ],
            [
                "role": "user",
                "content": "Question: \(query)\n\nMemory snippets:\n\n\(contextText)"
            ]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-5-nano",
            "messages": messages,
            "max_completion_tokens": 2000,
            "reasoning_effort": "low"
        ])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EmbeddingError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if http.statusCode == 429 { throw EmbeddingError.rateLimited }
            if http.statusCode == 401 { throw EmbeddingError.apiKeyMissing }
            let errMsg: String
            if let errObj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any],
               let msg = errObj["message"] as? String {
                errMsg = msg
            } else {
                errMsg = "HTTP \(http.statusCode)"
            }
            throw EmbeddingError.apiError(errMsg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw EmbeddingError.apiError("Unexpected response format")
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let finishReason = (choices.first?["finish_reason"] as? String) ?? "unknown"
            throw EmbeddingError.apiError("Model returned an empty response (finish_reason: \(finishReason)). Try a shorter question.")
        }

        return trimmed
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}
