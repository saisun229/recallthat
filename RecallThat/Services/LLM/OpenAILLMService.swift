import Foundation

final class OpenAILLMService: LLMService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func answer(query: String, context: [Memory]) async throws -> String {
        let contextText = context.prefix(5).enumerated().map { i, m in
            let snippet = m.ocrText.isEmpty ? m.title : String(m.ocrText.prefix(300))
            return "[\(i + 1)] \(m.title)\n\(snippet)"
        }.joined(separator: "\n\n")

        let messages: [[String: String]] = [
            [
                "role": "system",
                "content": "You are a personal memory assistant helping the user find and understand things they've saved. Based on the retrieved memory snippets, give a concise, helpful response to the user's search. If they asked a question, answer it. If they searched a topic, summarize what you found. Keep it to 2–3 sentences. Only use information from the provided snippets."
            ],
            [
                "role": "user",
                "content": "Search: \"\(query)\"\n\nMemories:\n\(contextText)"
            ]
        ]

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "messages": messages,
            "max_tokens": 400,
            "temperature": 0.2
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

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
