import Foundation

enum APIConfig {
    private static let keychainKey = "openai_api_key"

    // Keychain wins (user entered it at runtime); Info.plist is the build-time fallback.
    static var openAIKey: String {
        if let stored = KeychainHelper.load(key: keychainKey), !stored.isEmpty {
            return stored
        }
        let fromBundle = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String ?? ""
        // If Xcode didn't substitute the variable, the literal "$(OPENAI_API_KEY)" remains — treat as empty.
        if fromBundle.hasPrefix("$(") { return "" }
        return fromBundle
    }

    static var hasOpenAIKey: Bool { !openAIKey.isEmpty }

    static func saveOpenAIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.delete(key: keychainKey)
        } else {
            KeychainHelper.save(key: keychainKey, value: trimmed)
        }
    }

    static func deleteOpenAIKey() {
        KeychainHelper.delete(key: keychainKey)
    }
}
