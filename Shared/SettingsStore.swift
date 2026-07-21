import Foundation

/// Non-secret settings shared between the app and the keyboard via the App Group.
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults: UserDefaults

    private init() {
        let group = UserDefaults(suiteName: AppConstants.appGroupID)
        defaults = group ?? .standard
        defaults.register(defaults: [
            AppConstants.kEnableAI: true,
            AppConstants.kProvider: "gemini",
            AppConstants.kTheme: "system",
            AppConstants.kAutocorrect: true,
            AppConstants.kPredictions: true
        ])
    }

    var enableAI: Bool {
        get { defaults.bool(forKey: AppConstants.kEnableAI) }
        set { defaults.set(newValue, forKey: AppConstants.kEnableAI) }
    }
    var provider: String {
        get { defaults.string(forKey: AppConstants.kProvider) ?? "gemini" }
        set { defaults.set(newValue, forKey: AppConstants.kProvider) }
    }
    var theme: String {
        get { defaults.string(forKey: AppConstants.kTheme) ?? "system" }
        set { defaults.set(newValue, forKey: AppConstants.kTheme) }
    }
    var autocorrect: Bool {
        get { defaults.bool(forKey: AppConstants.kAutocorrect) }
        set { defaults.set(newValue, forKey: AppConstants.kAutocorrect) }
    }
    /// Auto-detected Gemini model, cached per process. Nil until first detection.
    var selectedModel: String? {
        get { defaults.string(forKey: AppConstants.kSelectedModel) }
        set { defaults.set(newValue, forKey: AppConstants.kSelectedModel) }
    }

    var predictions: Bool {
        get { defaults.bool(forKey: AppConstants.kPredictions) }
        set { defaults.set(newValue, forKey: AppConstants.kPredictions) }
    }
}
