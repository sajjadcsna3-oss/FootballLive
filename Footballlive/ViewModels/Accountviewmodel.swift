//
//  Accountviewmodel.swift
//  Footballlive
//
//  Created by Mac Mini on 24/09/2026.
//

import SwiftUI
import Combine
import AppKit
// MARK: - Profile, alert preferences, settings and Tempo Pro plans
@MainActor final class AccountViewModel: ObservableObject {
    // Profile
    @Published var name: String { didSet { UserDefaults.standard.set(name, forKey: "profileName") } }
    @Published private(set) var isPro = false
    @Published private(set) var metrics = UsageMetricsService.shared
    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "TF" : String(letters).uppercased()
    }
    var planName: String { isPro ? "Tempo Pro" : "Free plan" }
    var teamsFollowed: Int { UserDefaults.standard.stringArray(forKey: "followedTeamNames")?.count ?? 0 }
    var usage: [StatItem] {
        [StatItem(label: "Matches followed", value: "\(metrics.matchesFollowed)"),
         StatItem(label: "Alerts delivered", value: "\(metrics.alertsDelivered)"),
         StatItem(label: "AI reads used", value: isPro ? "Unlimited" : "\(EntitlementService.shared.monthlyAIUsage) / 20"),
         StatItem(label: "Momentum peaks caught", value: "\(metrics.momentumPeaks)")]
    }

    // Alerts (shared by Follow Setup and Alerts & Profile)
    @Published var threshold: Double { didSet { UserDefaults.standard.set(threshold, forKey: "excitementThreshold") } }
    @Published var enabledAlerts: Set<AlertKind> { didSet { UserDefaults.standard.set(enabledAlerts.map(\.rawValue), forKey: "enabledAlerts") } }
    var thresholdText: String { String(format: "%.1f", threshold) }
    func binding(for kind: AlertKind) -> Binding<Bool> {
        Binding(get: { self.enabledAlerts.contains(kind) },
                set: { on in
                    // SwiftUI can invoke a custom Binding setter while it is still
                    // reconciling the current view. Publish on the next main-actor
                    // turn so ObservableObject never changes during that update.
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(for: .milliseconds(1))
                        guard let self, kind.clientAvailable else { return }
                        if on { self.enabledAlerts.insert(kind) }
                        else { self.enabledAlerts.remove(kind) }

                        if on { _ = try? await NotificationService.shared.requestAuthorization() }
                        if kind == .recap {
                            try? await NotificationService.shared.scheduleWeeklyRecap(enabled: on)
                        }
                    }
                })
    }

    // Settings
    @Published var darkAppearance: Bool { didSet { UserDefaults.standard.set(darkAppearance, forKey: "darkAppearance") } }
    @Published var compactRows: Bool { didSet { UserDefaults.standard.set(compactRows, forKey: "compactRows") } }
    @Published var autoplayHighlights: Bool { didSet { UserDefaults.standard.set(autoplayHighlights, forKey: "autoplayHighlights"); NotificationCenter.default.post(name: .autoplayPreferenceChanged, object: autoplayHighlights) } }
    // MenuBarExtra may write its current `isInserted` value back while the scene
    // graph is updating. @Published emits even when that value is unchanged,
    // which creates a scene-update feedback loop. Publish only real changes.
    private var menuBarScoreValue: Bool
    var menuBarScore: Bool {
        get { menuBarScoreValue }
        set {
            guard newValue != menuBarScoreValue else { return }
            objectWillChange.send()
            menuBarScoreValue = newValue
            UserDefaults.standard.set(newValue, forKey: "menuBarScore")
        }
    }
    @Published var languageCode: String { didSet { UserDefaults.standard.set(languageCode, forKey: "languageCode"); NotificationCenter.default.post(name: .languagePreferenceChanged, object: languageCode) } }
    @Published var kickoffTimeMode: String { didSet { UserDefaults.standard.set(kickoffTimeMode, forKey: "kickoffTimeMode") } }
    let supportedLanguages = L10n.supported
    private var cancellables = Set<AnyCancellable>()

    // Claims here describe only functionality that currently exists in the app.
    let plans = [
        PlanInfo(id: "free", name: "Free", price: "$0", unit: "", note: "What you have now", noteColorHex: "7B8088",
                 features: ["Live scores and match center", "5 followed teams", "20 shared AI requests per month", "Local alerts while data is available"], button: "Current plan", isFeatured: false),
        PlanInfo(id: "monthly", name: "Pro Monthly", price: "—", unit: "/mo", note: "Flexible plan", noteColorHex: "C4F135",
                 features: ["Unlimited followed teams", "Higher AI usage subject to service limits", "AI match and table reads", "In-app momentum-surge alerts"], button: "Choose monthly", isFeatured: true),
        PlanInfo(id: "annual", name: "Pro Annual", price: "—", unit: "/yr", note: "Annual billing", noteColorHex: "3B6FE8",
                 features: ["Everything in Pro Monthly", "One annual App Store subscription"], button: "Choose annual", isFeatured: false)]

    init() {
        let defaults = UserDefaults.standard
        threshold = defaults.object(forKey: "excitementThreshold") as? Double ?? 6.4
        let savedAlerts = defaults.stringArray(forKey: "enabledAlerts")?.compactMap(AlertKind.init(rawValue:))
        enabledAlerts = Set(savedAlerts ?? [.goals, .surge, .startingSoon, .recap])
        darkAppearance = defaults.object(forKey: "darkAppearance") as? Bool ?? true
        compactRows = defaults.object(forKey: "compactRows") as? Bool ?? false
        autoplayHighlights = defaults.object(forKey: "autoplayHighlights") as? Bool ?? true
        menuBarScoreValue = defaults.object(forKey: "menuBarScore") as? Bool ?? true
        let savedLanguage = defaults.string(forKey: "languageCode") ?? "system"
        languageCode = L10n.supported.contains(where: { $0.id == savedLanguage }) ? savedLanguage : "system"
        kickoffTimeMode = defaults.string(forKey: "kickoffTimeMode") ?? "local"
        let systemName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        name = defaults.string(forKey: "profileName") ?? (systemName.isEmpty ? "Football Fan" : systemName)
        EntitlementService.shared.$plan
            .map { $0 == .tempoPro }
            .receive(on: RunLoop.main).assign(to: &$isPro)
        EntitlementService.shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        UsageMetricsService.shared.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    var selectedLanguageName: String { supportedLanguages.first(where: { $0.id == languageCode })?.name ?? "System Default" }
    var locale: Locale { languageCode == "system" ? .autoupdatingCurrent : Locale(identifier: languageCode) }
    var layoutDirection: LayoutDirection { ["ar", "ur", "fa"].contains(String(locale.identifier.prefix(2))) ? .rightToLeft : .leftToRight }
    var kickoffTimeZone: TimeZone { kickoffTimeMode == "utc" ? TimeZone(secondsFromGMT: 0)! : .autoupdatingCurrent }
    var kickoffTimeDescription: String {
        kickoffTimeMode == "utc" ? "UTC" : (TimeZone.autoupdatingCurrent.localizedName(for: .shortStandard, locale: locale) ?? TimeZone.autoupdatingCurrent.identifier)
    }
    func kickoffString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = kickoffTimeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension Notification.Name {
    static let autoplayPreferenceChanged = Notification.Name("autoplayPreferenceChanged")
    static let languagePreferenceChanged = Notification.Name("languagePreferenceChanged")
}
