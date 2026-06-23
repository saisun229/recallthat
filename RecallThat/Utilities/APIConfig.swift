import Foundation

enum APIConfig {
    private static let consentKey = "hasConsentedToOpenAISharing"

    static var openAIKey: String {
        let key = Bundle.main.object(forInfoDictionaryKey: "OpenAIAPIKey") as? String ?? ""
        // Guard against unexpanded Xcode variable literal when env var wasn't set at build time
        if key.hasPrefix("$(") { return "" }
        return key
    }

    static var hasOpenAIKey: Bool { !openAIKey.isEmpty }

    /// Explicit user permission to send OCR text to OpenAI, set during onboarding and changeable in Settings.
    static var hasUserConsent: Bool {
        UserDefaults.standard.bool(forKey: consentKey)
    }

    static func setUserConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: consentKey)
    }

    /// True only when an API key is configured AND the user has explicitly agreed to share OCR text with OpenAI.
    static var aiFeaturesEnabled: Bool { hasOpenAIKey && hasUserConsent }
}
