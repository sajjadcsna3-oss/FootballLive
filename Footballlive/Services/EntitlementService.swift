import Foundation
import Combine

enum AppPlan: String { case free, tempoPro }

enum PremiumCapability {
    case unlimitedTeams, unlimitedAI, advancedMomentum, momentumAlerts
    case historicalArchive, exportReports
}

/// The single source of truth for plan rules and metered usage.
@MainActor
final class EntitlementService: ObservableObject {
    static let shared = EntitlementService()

    static let freeTeamLimit = 5
    static let freeMonthlyAILimit = 20

    @Published private(set) var plan: AppPlan = .free
    @Published private(set) var monthlyAIUsage = 0
    @Published private(set) var usageMonth = ""

    private let store: StoreKitService
    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    private init(store: StoreKitService, defaults: UserDefaults) {
        self.store = store
        self.defaults = defaults
        refreshMonthlyUsage()
        store.$purchasedIDs
            .map { $0.isDisjoint(with: StoreKitService.proProductIDs) ? AppPlan.free : AppPlan.tempoPro }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.plan = $0 }
            .store(in: &cancellables)
    }

    private convenience init() { self.init(store: StoreKitService.shared, defaults: .standard) }

    var isPro: Bool { plan == .tempoPro }
    var remainingAIRequests: Int? {
        isPro ? nil : max(0, Self.freeMonthlyAILimit - monthlyAIUsage)
    }
    var canUseAI: Bool { isPro || monthlyAIUsage < Self.freeMonthlyAILimit }
    func canFollow(teamCount: Int) -> Bool { isPro || teamCount < Self.freeTeamLimit }

    func has(_ capability: PremiumCapability) -> Bool {
        switch capability {
        case .unlimitedTeams, .unlimitedAI, .advancedMomentum, .momentumAlerts:
            return isPro
        case .historicalArchive, .exportReports:
            // These capabilities are intentionally unavailable until the product exists.
            return false
        }
    }

    @discardableResult
    func consumeAIRequest() -> Bool {
        refreshMonthlyUsage()
        guard canUseAI else { return false }
        guard !isPro else { return true }
        monthlyAIUsage += 1
        defaults.set(monthlyAIUsage, forKey: usageCountKey)
        defaults.set(usageMonth, forKey: usageMonthKey)
        return true
    }

    func refreshMonthlyUsage(now: Date = Date()) {
        let current = Self.monthIdentifier(for: now)
        let savedMonth = defaults.string(forKey: usageMonthKey)
        if savedMonth != current {
            usageMonth = current
            monthlyAIUsage = 0
            defaults.set(current, forKey: usageMonthKey)
            defaults.set(0, forKey: usageCountKey)
        } else {
            usageMonth = current
            monthlyAIUsage = max(0, defaults.integer(forKey: usageCountKey))
        }
    }

    private var usageCountKey: String { "tempo.ai.monthly.count" }
    private var usageMonthKey: String { "tempo.ai.monthly.period" }
    private static func monthIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
