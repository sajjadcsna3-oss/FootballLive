import Foundation
import Combine

@MainActor final class APIKeySettingsViewModel: ObservableObject {
    @Published var goalInput = ""
    @Published var geminiInput = ""
    @Published private(set) var hasGoalKey = false
    @Published private(set) var hasGeminiKey = false
    @Published var message: String?

    init() { refresh() }

    func saveGoal() { save(goalInput, key: .goal); goalInput = "" }
    func saveGemini() { save(geminiInput, key: .gemini); geminiInput = "" }
    func removeGoal() { remove(.goal) }
    func removeGemini() { remove(.gemini) }

    private func save(_ value: String, key: KeychainService.Key) {
        do { try KeychainService.save(value, for: key); message = L10n.text("API key saved securely in macOS Keychain."); refresh() }
        catch { message = error.localizedDescription }
    }
    private func remove(_ key: KeychainService.Key) {
        do { try KeychainService.delete(key); message = L10n.text("Stored API key removed."); refresh() }
        catch { message = error.localizedDescription }
    }
    private func refresh() {
        hasGoalKey = KeychainService.read(.goal) != nil
        hasGeminiKey = KeychainService.read(.gemini) != nil
    }
}
