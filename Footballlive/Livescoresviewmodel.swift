import SwiftUI
import Combine

@MainActor final class LiveScoresViewModel: ObservableObject {
    @Published private(set) var leagues: [LeagueGroup] = []
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var commentary: [CommentaryItem] = []
    @Published private(set) var featuredFixture: Fixture?
    private let service: GoalAPIService
    private var lastLoaded: Date?
    private var commentaryLoadedAt: Date?
    private var commentaryFixtureID: String?
    private var favoriteIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "favoriteFixtureIDs") ?? [])
    private var lastScores: [String: (Int, Int)] = [:]
    private var isLoading = false
    init(service: GoalAPIService? = nil) { self.service = service ?? .shared }

    func load(force: Bool = false) async {
        guard !isLoading else { return }
        if !force, let lastLoaded, Date().timeIntervalSince(lastLoaded) < 25 { return }
        isLoading = true
        defer { isLoading = false }
        if state == .idle { state = .loading }
        do {
            var fixtures = try await service.liveFixtures().filter(\.isLive)
            await detectFollowedTeamGoals(in: fixtures)
            fixtures = fixtures.map { var f = $0; f.isFavorite = favoriteIDs.contains(f.id); return f }
            let grouped = Dictionary(grouping: fixtures, by: \Fixture.league)
            leagues = grouped.map { LeagueGroup(league: $0.key, matches: $0.value.sorted { ($0.kickoff ?? .distantPast) < ($1.kickoff ?? .distantPast) }) }.sorted { $0.name < $1.name }
            featuredFixture = fixtures.first
            if let featuredFixture,
               commentaryFixtureID != featuredFixture.id || commentaryLoadedAt.map({ Date().timeIntervalSince($0) > 60 }) != false {
                commentary = (try? await service.commentary(id: featuredFixture.id)) ?? []
                commentaryFixtureID = featuredFixture.id
                commentaryLoadedAt = Date()
            } else if featuredFixture == nil {
                commentary = []
                commentaryFixtureID = nil
            }
            lastLoaded = Date(); state = fixtures.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            // View disappearance is expected cancellation, not a user-facing API error.
        } catch NetworkError.offline {
            state = .offline
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
    private func detectFollowedTeamGoals(in fixtures: [Fixture]) async {
        let enabled = Set(UserDefaults.standard.stringArray(forKey: "enabledAlerts") ?? [])
        let followed = Set(UserDefaults.standard.stringArray(forKey: "followedTeamNames") ?? [])
        for fixture in fixtures {
            guard let home = fixture.homeScore, let away = fixture.awayScore else { continue }
            if let old = lastScores[fixture.id], enabled.contains(AlertKind.goals.rawValue) {
                let followedMatch = followed.contains(fixture.homeTeam.name) || followed.contains(fixture.awayTeam.name)
                if followedMatch && (home > old.0 || away > old.1) {
                    try? await NotificationService.shared.deliver(title: L10n.text("Goal"), body: "\(fixture.homeTeam.name) \(home)–\(away) \(fixture.awayTeam.name)", id: "goal-\(fixture.id)-\(home)-\(away)")
                }
            }
            lastScores[fixture.id] = (home, away)
        }
    }
    func toggleStar(_ fixture: Fixture) {
        if favoriteIDs.contains(fixture.id) { favoriteIDs.remove(fixture.id) } else { favoriteIDs.insert(fixture.id); UsageMetricsService.shared.recordMatchFollowed(id: fixture.id) }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: "favoriteFixtureIDs")
        for leagueIndex in leagues.indices { if let i = leagues[leagueIndex].matches.firstIndex(where: { $0.id == fixture.id }) { leagues[leagueIndex].matches[i].isFavorite.toggle() } }
    }
}
