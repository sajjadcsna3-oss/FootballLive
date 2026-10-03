import Foundation
import Combine

/// Records an affirmative, revocable choice before user-entered text is sent
/// to the app's backend and its third-party AI processor.
@MainActor final class AIConsentService: ObservableObject {
    static let shared = AIConsentService()

    @Published private(set) var hasConsent: Bool
    private let defaults = UserDefaults.standard
    private static let consentKey = "privacy.aiThirdPartyConsent.v1"

    private init() {
        hasConsent = defaults.bool(forKey: Self.consentKey)
    }

    func grant() {
        defaults.set(true, forKey: Self.consentKey)
        hasConsent = true
    }

    func revoke() {
        defaults.removeObject(forKey: Self.consentKey)
        hasConsent = false
    }
}
