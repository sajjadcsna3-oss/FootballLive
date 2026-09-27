import Foundation
import Security

struct Language { let code: String; let name: String }
let languages = [
    Language(code: "es", name: "Spanish"), Language(code: "fr", name: "French"), Language(code: "de", name: "German"),
    Language(code: "it", name: "Italian"), Language(code: "pt-BR", name: "Brazilian Portuguese"), Language(code: "pt-PT", name: "European Portuguese"),
    Language(code: "nl", name: "Dutch"), Language(code: "pl", name: "Polish"), Language(code: "ru", name: "Russian"),
    Language(code: "uk", name: "Ukrainian"), Language(code: "tr", name: "Turkish"), Language(code: "ar", name: "Arabic"),
    Language(code: "ur", name: "Urdu"), Language(code: "fa", name: "Persian"), Language(code: "hi", name: "Hindi"),
    Language(code: "bn", name: "Bengali"), Language(code: "pa", name: "Punjabi"), Language(code: "id", name: "Indonesian"),
    Language(code: "ms", name: "Malay"), Language(code: "vi", name: "Vietnamese"), Language(code: "th", name: "Thai"),
    Language(code: "fil", name: "Filipino"), Language(code: "zh-Hans", name: "Simplified Chinese"), Language(code: "zh-Hant", name: "Traditional Chinese"),
    Language(code: "ja", name: "Japanese"), Language(code: "ko", name: "Korean"), Language(code: "sv", name: "Swedish"),
    Language(code: "nb", name: "Norwegian Bokmål"), Language(code: "da", name: "Danish"), Language(code: "fi", name: "Finnish"),
    Language(code: "el", name: "Greek"), Language(code: "cs", name: "Czech"), Language(code: "ro", name: "Romanian"), Language(code: "hu", name: "Hungarian")
]

let keys = Array(Set([
    "Live Scores", "Match Center", "Highlights", "Leagues", "Teams", "Co-Commentator", "Follow Setup", "Alerts & Profile", "Settings", "Tempo Pro",
    "Live", "Discover", "Intelligence", "Account", "Scores · AI Analysis", "Today · All competitions", "Real match data", "Recent GOAL API videos", "Standings and competition data", "Club profile", "Grounded in current match data", "Choose teams and alerts", "Smart notifications", "Appearance, language, account and legal", "Plans & billing",
    "Loading live scores…", "No live matches right now.", "Check back soon or retry to refresh live data.", "You're offline.", "Check your internet connection.", "Unable to load scores.", "Retry", "Live commentary", "Commentary is not available for this match.", "No live match selected.", "Your alert budget", "of %lld today", "Tempo only alerts when a match crosses your saved threshold.",
    "Loading match center…", "Select a match from Live Scores.", "Unable to load match.", "Momentum Pulse", "Calculated from available real events", "Not available", "Statistics", "Timeline", "No match events available.", "Excitement score", "Calculated locally from available match data.",
    "Loading highlights…", "No highlights are currently available.", "GOAL API has not returned any playable videos.", "Unable to load highlights.", "Latest", "Highlight", "Open match center", "Back to highlights", "Up next", "No more highlights available.", "AI clip breakdown", "Match context is not available for this video.", "This video cannot be played.", "GOAL API did not return a playable URL.", "Unable to play this video.", "The video provider rejected the stream or it is no longer available.",
    "Loading competitions…", "No competitions are available.", "Unable to load competitions.", "Competitions", "Club", "Form", "No standings are available for this competition and season.", "AI Table Read", "Generate grounded read", "Reading the real table…", "Select a team from Follow Setup or a league.", "Loading team…", "Unable to load team.", "Following", "Follow", "Squad", "Squad data is not available.", "Next fixtures", "No upcoming fixtures.",
    "Ask about the selected match.", "Select a live match first. The AI will never invent missing football data.", "Answers use only the match data shown in Match Center.", "Clear", "What changed tactically?", "Explain the recent momentum", "Who has been more dangerous?", "Summarise this match", "Free AI limit reached. Upgrade to Tempo Pro for unlimited reads.",
    "Who should we watch for you?", "Pick your teams. Tempo learns which moments actually pull you in and quiets everything else.", "Sports", "Football", "Continue", "Skip for now", "How loud should Tempo be?", "Set the excitement threshold once. Tempo stays silent below it and you can move it any time.", "Everything", "Only the good stuff", "Finals only", "Back", "Your feed is ready.", "Open Tempo", "See Pro — 7 days free", "Teams followed", "Sports", "Threshold",
    "Excitement threshold", "Only get pinged when the momentum engine says a match is worth looking up from your desk.", "Goals for followed teams", "Local alerts when the app receives a followed-team goal", "Momentum surge", "Local alerts when calculated excitement crosses your threshold", "Every goal, every league", "Requires a backend for reliable background delivery", "Match starting soon", "Schedules a local reminder for known fixtures", "Transfer & injury news", "Unavailable until a backend classifies and pushes confirmed reports", "Weekly recap", "Schedules a weekly local reminder", "Go Pro", "Edit profile", "This week", "Matches followed", "Alerts delivered", "AI reads used", "Momentum peaks caught", "Profile", "Display name", "Stored only on this Mac and used for your profile label.", "Cancel", "Save",
    "Unlock the full Tempo read", "Momentum on every match, unlimited AI co-commentary, unlimited teams and leagues.", "Tempo Pro active", "View plans", "General", "Dark appearance", "Tempo is designed dark; light mode is high-contrast only", "Compact rows", "Fit roughly four more matches per screen", "Autoplay highlights", "Play the next clip automatically in the player", "Menu-bar live score", "Keep one followed match in the macOS menu bar", "Language", "Interface and AI commentary language", "Kickoff times", "Choose local time or UTC", "Local · %@", "UTC", "Restore purchases", "Recover an existing App Store subscription", "API Connections", "Others", "Share Tempo", "Send the app to a friend", "Rate on the App Store", "Thirty seconds, genuinely helps", "Terms of Use", "Privacy Policy",
    "See the game move\nbefore it happens.", "The momentum engine and AI co-commentator run on every match, in every league you follow.", "Cancel anytime · 7-day trial on annual", "Free", "What you have now", "Live scores, all sports", "5 followed teams", "20 AI reads per month", "Standard alerts", "Current plan", "Pro Monthly", "Most popular", "Momentum engine on every match", "Unlimited AI co-commentary", "Unlimited teams and leagues", "Multi-match live wall", "No ads, ever", "Start 7-day trial", "Pro Annual", "Save 29%", "Everything in Pro Monthly", "Season-long momentum archive", "Export match reports", "Early access to new sports", "Choose annual", "Unavailable",
    "Subscription products are not configured in App Store Connect.", "Tempo Pro is active.", "The purchase could not be verified.", "The purchase is pending approval.", "The purchase could not be completed.", "Purchases restored.", "No active subscription was found.", "Goal", "Match starting soon", "Your weekly football recap", "Open Tempo to catch up on followed teams.", "Football Live", "System Default"
    , "%@ · %lld teams followed", "%lld live now", "%@ vs %@ starts in 10 minutes.", "%@ vs %@ crossed your %.1f threshold.", "API key saved securely in macOS Keychain.", "Stored API key removed."
])).sorted()

func keychainAPIKey() -> String? {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "com.Sajjad.project.Footballlive.api-keys", kSecAttrAccount as String: "GEMINI_API_KEY", kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
    return String(data: data, encoding: .utf8)
}
func escaped(_ value: String) -> String { value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n") }
func write(_ values: [String: String], code: String, root: URL) throws {
    let folder = root.appendingPathComponent("Footballlive/\(code).lproj")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let content = keys.map { "\"\(escaped($0))\" = \"\(escaped(values[$0] ?? $0))\";" }.joined(separator: "\n") + "\n"
    try content.write(to: folder.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
}

func translate(_ keys: [String], to language: Language, apiKey: String) async throws -> [String] {
    let prompt = "Translate this football macOS app JSON string array into \(language.name). Preserve %@, %lld, punctuation, Tempo, GOAL API, Gemini API, StoreKit and product names. Return only a JSON array in identical order. Use concise natural UI language.\n" + String(data: try JSONEncoder().encode(keys), encoding: .utf8)!
    for attempt in 1...6 {
        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent")!)
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type"); request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["contents": [["parts": [["text": prompt]]]], "generationConfig": ["responseMimeType": "application/json", "temperature": 0.1, "maxOutputTokens": 16384]])
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200,
           let rootJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = rootJSON["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String,
           let translated = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String], translated.count == keys.count { return translated }
        if attempt < 6 { try await Task.sleep(for: .seconds([429, 500, 503].contains(status) ? attempt * 5 : attempt * 2)); continue }
        let responseText = String(data: data, encoding: .utf8)?.prefix(500) ?? "No response body"
        throw NSError(domain: "Localization", code: 2, userInfo: [NSLocalizedDescriptionKey: "Translation failed for \(language.code) (HTTP \(status)): \(responseText)"])
    }
    throw NSError(domain: "Localization", code: 3, userInfo: [NSLocalizedDescriptionKey: "Translation retries exhausted for \(language.code)"])
}

@main struct Generator {
    static func main() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        try write(Dictionary(uniqueKeysWithValues: keys.map { ($0, $0) }), code: "en", root: root)
        guard let apiKey = keychainAPIKey() else { throw NSError(domain: "Localization", code: 1, userInfo: [NSLocalizedDescriptionKey: "Gemini key was not found in Keychain."]) }
        for language in languages {
            let destination = root.appendingPathComponent("Footballlive/\(language.code).lproj/Localizable.strings")
            let existing: [String: String]
            if let data = try? Data(contentsOf: destination), let values = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] { existing = values } else { existing = [:] }
            let missing = keys.filter { existing[$0] == nil }
            if missing.isEmpty { print("Kept \(language.code)"); continue }
            let translated = try await translate(missing, to: language, apiKey: apiKey)
            var merged = existing
            for (key, value) in zip(missing, translated) { merged[key] = value }
            try write(merged, code: language.code, root: root)
            print("Generated \(language.code)")
            try await Task.sleep(for: .seconds(2))
        }
    }
}
