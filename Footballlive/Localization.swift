import Foundation

struct AppLanguage: Identifiable, Hashable {
    let id: String
    let name: String
}

enum L10n {
    static let supported: [AppLanguage] = [
        .init(id: "system", name: "System Default"),
        .init(id: "en", name: "English"), .init(id: "es", name: "Español"),
        .init(id: "fr", name: "Français"), .init(id: "de", name: "Deutsch"),
        .init(id: "it", name: "Italiano"), .init(id: "pt-BR", name: "Português (Brasil)"),
        .init(id: "pt-PT", name: "Português (Portugal)"), .init(id: "nl", name: "Nederlands"),
        .init(id: "pl", name: "Polski"), .init(id: "ru", name: "Русский"),
        .init(id: "uk", name: "Українська"), .init(id: "tr", name: "Türkçe"),
        .init(id: "ar", name: "العربية"), .init(id: "ur", name: "اردو"),
        .init(id: "fa", name: "فارسی"), .init(id: "hi", name: "हिन्दी"),
        .init(id: "bn", name: "বাংলা"), .init(id: "pa", name: "ਪੰਜਾਬੀ"),
        .init(id: "id", name: "Bahasa Indonesia"), .init(id: "ms", name: "Bahasa Melayu"),
        .init(id: "vi", name: "Tiếng Việt"), .init(id: "th", name: "ไทย"),
        .init(id: "fil", name: "Filipino"), .init(id: "zh-Hans", name: "简体中文"),
        .init(id: "zh-Hant", name: "繁體中文"), .init(id: "ja", name: "日本語"),
        .init(id: "ko", name: "한국어"), .init(id: "sv", name: "Svenska"),
        .init(id: "nb", name: "Norsk bokmål"), .init(id: "da", name: "Dansk"),
        .init(id: "fi", name: "Suomi"), .init(id: "el", name: "Ελληνικά"),
        .init(id: "cs", name: "Čeština"), .init(id: "ro", name: "Română"),
        .init(id: "hu", name: "Magyar")
    ]

    static var selectedCode: String { UserDefaults.standard.string(forKey: "languageCode") ?? "system" }
    static var locale: Locale { selectedCode == "system" ? .autoupdatingCurrent : Locale(identifier: selectedCode) }
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let code = selectedCode == "system" ? (Locale.preferredLanguages.first ?? "en") : selectedCode
        let candidates = [code, code.replacingOccurrences(of: "-", with: "_"), String(code.prefix(2)), "en"]
        let bundle = candidates.lazy.compactMap { Bundle.main.path(forResource: $0, ofType: "lproj") }.compactMap(Bundle.init(path:)).first ?? .main
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: locale, arguments: arguments)
    }
}
