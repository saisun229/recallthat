import Foundation

enum APIConfig {
    static var openAIKey: String {
        let key = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String ?? ""
        // Guard against unexpanded Xcode variable literal when env var wasn't set at build time
        if key.hasPrefix("$(") { return "" }
        return key
    }

    static var hasOpenAIKey: Bool { !openAIKey.isEmpty }
}
