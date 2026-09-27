import SwiftUI
import Combine

@MainActor final class MatchCenterViewModel: ObservableObject {
    @Published private(set) var fixture: Fixture?
    @Published private(set) var statistics: [MatchStatistic] = []
    @Published private(set) var events: [MatchEvent] = []
    @Published private(set) var lineups: [MatchLineup] = []
    @Published private(set) var commentary: [CommentaryItem] = []
    @Published private(set) var momentum: [MomentumPoint] = []
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var excitement = 0.0
    private let service: GoalAPIService
    init(service: GoalAPIService? = nil) { self.service = service ?? .shared }

    func load(_ selected: Fixture?, force: Bool = false) async {
        guard let selected else { state = .empty; return }
        if !force, fixture?.id == selected.id, state == .loaded { return }
        state = .loading
        do {
            async let details = service.fixture(id: selected.id)
            async let eventData = service.events(id: selected.id)
            async let cardData = service.cards(id: selected.id)
            async let substitutionData = service.substitutions(id: selected.id)
            async let statsData = service.statistics(id: selected.id)
            let loadedFixture = try await details
            let combinedEvents = ((try? await eventData) ?? []) + ((try? await cardData) ?? []) + ((try? await substitutionData) ?? [])
            let loadedEvents = Array(Dictionary(grouping: combinedEvents, by: { "\($0.minute ?? -1)|\($0.type)|\($0.playerName ?? "")|\($0.detail ?? "")" }).compactMap { $0.value.first })
            let loadedStats = (try? await statsData) ?? []
            fixture = loadedFixture; events = loadedEvents.sorted { ($0.minute ?? 0) > ($1.minute ?? 0) }; statistics = loadedStats
            momentum = AnalyticsEngine.momentum(events: loadedEvents, statistics: loadedStats, homeTeamID: loadedFixture.homeTeam.id, currentMinute: loadedFixture.elapsed ?? 90)
            excitement = AnalyticsEngine.excitement(fixture: loadedFixture, events: loadedEvents, statistics: loadedStats, momentum: momentum, followsTeam: false)
            let threshold = UserDefaults.standard.object(forKey: "excitementThreshold") as? Double ?? 6.4
            if excitement >= threshold {
                UsageMetricsService.shared.recordMomentumPeak(fixtureID: loadedFixture.id)
                let enabled = Set(UserDefaults.standard.stringArray(forKey: "enabledAlerts") ?? [])
                if enabled.contains(AlertKind.surge.rawValue), EntitlementService.shared.has(.momentumAlerts) {
                    try? await NotificationService.shared.deliver(title: L10n.text("Momentum surge"), body: L10n.text("%@ vs %@ crossed your %.1f threshold.", loadedFixture.homeTeam.name, loadedFixture.awayTeam.name, threshold), id: "surge-\(loadedFixture.id)")
                }
            }
            async let lineupData = service.lineups(id: selected.id, fixture: loadedFixture)
            async let commentaryData = service.commentary(id: selected.id)
            lineups = (try? await lineupData) ?? []; commentary = (try? await commentaryData) ?? []
            state = .loaded
        } catch NetworkError.offline { state = .offline }
        catch { state = .failed(error.localizedDescription) }
    }
    var timeline: [TimelineEvent] { events.map { event in
        let lower = event.type.lowercased(); let kind: TimelineEvent.Kind = lower.contains("goal") ? (event.teamId == fixture?.homeTeam.id ? .goalHome : .goalAway) : lower.contains("yellow") ? .yellow : lower.contains("red") ? .red : lower.contains("sub") ? .substitution : .other
        return TimelineEvent(time: event.minute.map { "\($0)'" } ?? "–", kind: kind, title: event.type, detail: [event.playerName, event.detail].compactMap { $0 }.joined(separator: " · "))
    } }
    var statItems: [StatItem] { statistics.prefix(4).map { StatItem(label: $0.name, value: "\($0.home.map(MatchStatistic.format) ?? "–") – \($0.away.map(MatchStatistic.format) ?? "–")") } }
}
