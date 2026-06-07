import Foundation

final class OpenAIEmbeddingService: EmbeddingService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func embed(text: String) async throws -> [Float] {
        let url = URL(string: "https://api.openai.com/v1/embeddings")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": "text-embedding-3-small",
            "input": String(text.prefix(8000))
        ])

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EmbeddingError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if http.statusCode == 429 { throw EmbeddingError.rateLimited }
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
              let dataArr = json["data"] as? [[String: Any]],
              let vector = dataArr.first?["embedding"] as? [Double] else {
            throw EmbeddingError.apiError("Unexpected response format")
        }

        return vector.map(Float.init)
    }
}
