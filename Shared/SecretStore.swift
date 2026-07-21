import Foundation
import Security

/// Stores the Gemini API key. There is no shared-container requirement: each
/// process (app, keyboard) keeps its own copy in its Keychain and UserDefaults,
/// and the key is handed to the keyboard once via the clipboard ("Copy Key to
/// Clipboard" in the app → "Paste API Key" in the keyboard panel). If an App
/// Group container happens to be available at runtime, it is used as an extra
/// mirror so the hand-off can be automatic — but nothing depends on it.
final class SecretStore {
    static let shared = SecretStore()
    private init() {}

    /// Optional shared defaults; nil or sandbox-local when no group is provisioned.
    private let groupDefaults = UserDefaults(suiteName: AppConstants.appGroupID)

    @discardableResult
    func saveAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return false }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)

        UserDefaults.standard.set(trimmed, forKey: AppConstants.kApiKeyMirror)
        groupDefaults?.set(trimmed, forKey: AppConstants.kApiKeyMirror)
        groupDefaults?.set(true, forKey: AppConstants.kApiKeyPresent)
        return true
    }

    func apiKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let key = String(data: data, encoding: .utf8), !key.isEmpty {
            return key
        }
        if let local = UserDefaults.standard.string(forKey: AppConstants.kApiKeyMirror), !local.isEmpty {
            return local
        }
        if let mirrored = groupDefaults?.string(forKey: AppConstants.kApiKeyMirror), !mirrored.isEmpty {
            // Promote to this process's own storage for next launch.
            saveAPIKey(mirrored)
            return mirrored
        }
        return nil
    }

    var hasKey: Bool { apiKey() != nil }

    func clear() {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: AppConstants.keychainService,
            kSecAttrAccount as String: AppConstants.keychainAccount
        ]
        SecItemDelete(base as CFDictionary)
        UserDefaults.standard.removeObject(forKey: AppConstants.kApiKeyMirror)
        groupDefaults?.removeObject(forKey: AppConstants.kApiKeyMirror)
        groupDefaults?.set(false, forKey: AppConstants.kApiKeyPresent)
    }
}
