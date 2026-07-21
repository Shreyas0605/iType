import Foundation

/// Builds the active `AIProvider` from stored settings. The UI calls this and
/// never constructs a provider itself, so new providers plug in here only.
enum AIProviderFactory {
    enum ProviderKind: String { case gemini }

    static func makeProvider() -> AIProvider? {
        guard let key = SecretStore.shared.apiKey(), !key.isEmpty else { return nil }
        switch ProviderKind(rawValue: SettingsStore.shared.provider) ?? .gemini {
        case .gemini:
            return GeminiProvider(apiKey: key)
        }
    }
}
