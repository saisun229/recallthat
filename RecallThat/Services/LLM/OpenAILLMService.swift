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
                You're chatting with someone about screenshots they saved because the content mattered to them. You've been handed the most relevant snippets from their library for this question — talk to them like a sharp friend who already read those screenshots, not like a search engine printing results.

                How to answer:
                - Open by directly answering the question in plain conversational language, the way you'd say it out loud — not by restating or listing the snippets
                - Weave the specific details (names, numbers, prices, dates, places) into natural sentences instead of dumping them as a list
                - Cite inline with [1], [2], etc. right after the fact it supports — never as a trailing "Sources:" block, the app already renders tappable cards for those
                - Use ONLY facts present in the snippets — never invent or assume anything beyond them
                - If the snippets only partly answer the question, say so naturally ("I found X, but not Y") instead of a disclaimer
                - Only switch to a bullet list when comparing several distinct items side by side; otherwise write in flowing sentences
                - Address the user as "you"; never refer to yourself as "I" doing the search — speak as if you simply recall what they saved
                - Vary your phrasing and sentence rhythm so consecutive answers don't feel templated
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
