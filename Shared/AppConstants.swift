import Foundation

/// App-wide constants shared between the main app and the keyboard extension.
enum AppConstants {
    /// App Group used to share the API key and settings across processes.
    /// Must match the value in both entitlements files.
    static let appGroupID = "group.com.test.aikeyboard"

    // Keychain (per-process; no shared access group required).
    static let keychainService = "com.test.aikeyboard.gemini"
    static let keychainAccount = "gemini_api_key"

    // Gemini. No hardcoded model: the provider queries the ListModels API and
    // picks a supported one. This list only ranks preferred name patterns and
    // provides last-resort fallbacks if listing ever fails.
    static let geminiPreferredPatterns = ["flash", "pro"]
    static let geminiFallbackModels = ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"]
    static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    // Settings keys (stored in the App Group UserDefaults)
    static let kEnableAI = "enable_ai"
    static let kProvider = "ai_provider"
    static let kTheme = "theme"
    static let kAutocorrect = "autocorrect"
    static let kPredictions = "predictions"
    static let kApiKeyMirror = "gemini_api_key_mirror"
    static let kApiKeyPresent = "api_key_present"
    static let kSelectedModel = "gemini_selected_model"

    static let defaultRewriteCount = 3
}
