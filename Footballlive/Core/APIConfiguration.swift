import Foundation

nonisolated enum APIConfiguration {
    static let goalBaseURL = URL(string: "https://api.goal-api.com/v1")!
    static let geminiBaseURL = URL(string: "https://generativelanguage.googleapis.com/v1beta")!
    static let geminiModel = "gemini-3.5-flash-lite"

    /// App Store builds must point at the Tempo backend. Provider secrets never
    /// belong in a distributed app. Debug builds may use Keychain keys locally.
    static var backendBaseURL: URL? {
        guard let value = configurationValue(named: "TEMPO_API_BASE_URL") else { return nil }
        return URL(string: value)
    }

    static let termsURL = URL(string: "https://sites.google.com/view/app-for-netflix/terms-of-use")
    static let privacyURL = URL(string: "https://sites.google.com/view/app-for-netflix/privacy-policy")

    /// Rights-sensitive provider assets stay off in production until the
    /// developer has written authorization from the relevant rights holders.
    static var allowsThirdPartyVisualAssets: Bool { configurationFlag(named: "FOOTBALLLIVE_ALLOW_PROVIDER_VISUALS") }
    static var allowsHighlightPlayback: Bool { configurationFlag(named: "FOOTBALLLIVE_ALLOW_PROVIDER_VIDEOS") }

    static var goalAPIKey: String? {
#if DEBUG
        configuredKey(.goal)
#else
        nil
#endif
    }
    static var geminiAPIKey: String? {
#if DEBUG
        configuredKey(.gemini)
#else
        nil
#endif
    }

    static func bootstrap() {
        _ = goalAPIKey
        _ = geminiAPIKey
    }

    private static func configuredKey(_ key: KeychainService.Key) -> String? {
        if let stored = KeychainService.read(key) { return stored }
        guard let development = developmentSecret(named: key.rawValue) else { return nil }
        try? KeychainService.save(development, for: key)
        return development
    }

    private static func developmentSecret(named name: String) -> String? {
        configurationValue(named: name)
    }

    private static func configurationValue(named name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name] ?? Bundle.main.object(forInfoDictionaryKey: name) as? String
        guard let value, !value.isEmpty, !value.contains("YOUR_") else { return nil }
        return value
    }

    private static func configuredURL(named name: String) -> URL? {
        guard let value = configurationValue(named: name),
              let url = URL(string: value),
              ["https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    private static func configurationFlag(named name: String) -> Bool {
        guard let value = configurationValue(named: name)?.lowercased() else { return false }
        return ["1", "true", "yes"].contains(value)
    }
}
