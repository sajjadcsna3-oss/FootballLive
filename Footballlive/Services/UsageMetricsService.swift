import Foundation
import Combine

/// Stores only real, locally observed app activity. Counters roll over every ISO week.
@MainActor final class UsageMetricsService: ObservableObject {
    static let shared = UsageMetricsService()
    @Published private(set) var matchesFollowed = 0
    @Published private(set) var alertsDelivered = 0
    @Published private(set) var aiReads = 0
    @Published private(set) var momentumPeaks = 0

    private let defaults = UserDefaults.standard
    private var weekKey: String {
        let parts = Calendar(identifier: .iso8601).dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(parts.yearForWeekOfYear ?? 0)-\(parts.weekOfYear ?? 0)"
    }
    private func key(_ name: String) -> String { "weekly.\(weekKey).\(name)" }

    private init() { refresh() }
    func refresh() {
        matchesFollowed = defaults.integer(forKey: key("matchesFollowed"))
        alertsDelivered = defaults.integer(forKey: key("alertsDelivered"))
        aiReads = defaults.integer(forKey: key("aiReads"))
        momentumPeaks = defaults.integer(forKey: key("momentumPeaks"))
    }
    func recordMatchFollowed(id: String) { recordUnique("matchesFollowed", id: id); refresh() }
    func recordAlertDelivered(id: String) { recordUnique("alertsDelivered", id: id); refresh() }
    func recordAIRead() { increment("aiReads"); refresh() }
    func recordMomentumPeak(fixtureID: String) { recordUnique("momentumPeaks", id: fixtureID); refresh() }

    private func increment(_ name: String) { defaults.set(defaults.integer(forKey: key(name)) + 1, forKey: key(name)) }
    private func recordUnique(_ name: String, id: String) {
        let idsKey = key("\(name).ids")
        var ids = Set(defaults.stringArray(forKey: idsKey) ?? [])
        guard ids.insert(id).inserted else { return }
        defaults.set(Array(ids), forKey: idsKey)
        increment(name)
    }
}
