import Foundation
import Security

nonisolated enum KeychainService {
    private static let service = "com.Sajjad.project.Footballlive.api-keys"

    enum Key: String { case goal = "GOAL_API_KEY", gemini = "GEMINI_API_KEY" }

    static func save(_ value: String, for key: Key) throws {
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanValue.isEmpty else { throw KeychainError.emptyValue }
        let account = key.rawValue
        let search: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        SecItemDelete(search as CFDictionary)
        var insert = search
        insert[kSecValueData as String] = Data(cleanValue.utf8)
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(insert as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    static func read(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: Key) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key.rawValue]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }

    enum KeychainError: LocalizedError {
        case emptyValue, status(OSStatus)
        var errorDescription: String? {
            switch self {
            case .emptyValue: return "The API key cannot be empty."
            case .status(let status): return SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)."
            }
        }
    }
}
