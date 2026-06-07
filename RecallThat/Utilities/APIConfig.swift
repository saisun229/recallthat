import Foundation

enum APIConfig {
    static var openAIKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String ?? ""
    }

    static var hasOpenAIKey: Bool { !openAIKey.isEmpty }
}
