import SwiftUI
import Combine

@MainActor final class LeaguesTeamsViewModel: ObservableObject {
    enum LeagueTab: String, CaseIterable { case standings = "Standings", fixtures = "Fixtures", results = "Results", scorers = "Top Scorers" }
    @Published private(set) var leagues: [League] = []
    @Published var selectedLeague: League?
    @Published private(set) var standings: [Standing] = []
    @Published var leagueTab: LeagueTab = .standings
    @Published private(set) var leagueFixtures: [Fixture] = []
    @Published private(set) var leagueResults: [Fixture] = []
    @Published private(set) var scorers: [TopScorer] = []
    @Published private(set) var leagueState: LoadState = .idle
    @Published private(set) var tableRead: String?
    @Published private(set) var tableReadState: LoadState = .idle
    @Published private(set) var liveCountsByLeague: [String: Int] = [:]
    @Published private(set) var team: Team?
    @Published private(set) var squad: [Player] = []
    @Published private(set) var fixtures: [Fixture] = []
    @Published private(set) var teamResults: [Fixture] = []
    @Published private(set) var teamMetrics: [TeamMetric] = []
    @Published private(set) var teamState: LoadState = .idle
    @Published var isFollowing = false
    @Published var followMessage: String?
    private let service: GoalAPIService
    private let gemini: GeminiService
    init(service: GoalAPIService? = nil, gemini: GeminiService? = nil) { self.service = service ?? .shared; self.gemini = gemini ?? .shared }

    func loadLeagues(force: Bool = false) async {
        if !force, !leagues.isEmpty { return }
        leagueState = .loading
        do {
            async let leagueRequest = service.leagues()
            async let liveRequest = service.liveFixtures()
            leagues = try await leagueRequest
                .filter { $0.isActive != false }
                .sorted {
                    if ($0.popularity ?? 0) == ($1.popularity ?? 0) { return $0.name < $1.name }
                    return ($0.popularity ?? 0) > ($1.popularity ?? 0)
                }
            let liveFixtures = (try? await liveRequest) ?? []
            liveCountsByLeague = Dictionary(grouping: liveFixtures.filter(\.isLive), by: { $0.league.id })
                .mapValues(\.count)
            let savedID = UserDefaults.standard.string(forKey: "selectedLeagueID")
            selectedLeague = selectedLeague ?? leagues.first(where: { $0.id == savedID }) ?? leagues.first
            if let selectedLeague { await loadStandings(selectedLeague) } else { leagueState = .empty }
        }
        catch NetworkError.offline { leagueState = .offline } catch { leagueState = .failed(error.localizedDescription) }
    }

    func liveCount(for league: League) -> Int { liveCountsByLeague[league.id, default: 0] }
    func loadStandings(_ league: League) async {
        selectedLeague = league
        UserDefaults.standard.set(league.id, forKey: "selectedLeagueID")
        leagueState = .loading
        tableRead = nil
        tableReadState = .idle
        do {
            async let standingData = service.standings(leagueID: league.id)
            async let teamData = service.leagueTeams(league.id)
            async let resultData = service.leagueResults(league.id)
            async let fixtureData = service.leagueFixtures(league.id)
            async let scorerData = service.topScorers(league.id)
            var loaded = try await standingData
            let teams = (try? await teamData) ?? []
            let results = (try? await resultData) ?? []
            leagueFixtures = (try? await fixtureData) ?? []
            leagueResults = results
            scorers = (try? await scorerData) ?? []
            let badges = Dictionary(teams.compactMap { team in team.badgeURL.map { (team.id, $0) } }, uniquingKeysWith: { first, _ in first })
            let forms = recentForm(from: results)
            loaded = loaded.map { standing in
                var value = standing
                value.team.badgeURL = value.team.badgeURL ?? badges[value.team.id]
                value.form = value.form ?? forms[value.team.id]
                return value
            }.sorted { lhs, rhs in
                lhs.position == rhs.position ? lhs.points > rhs.points : lhs.position < rhs.position
            }
            standings = loaded
            leagueState = loaded.isEmpty ? .empty : .loaded
        } catch NetworkError.offline { leagueState = .offline }
        catch { leagueState = .failed(error.localizedDescription) }
    }
    func generateTableRead() async {
        guard let league = selectedLeague, !standings.isEmpty else { return }
        if !EntitlementService.shared.canUseAI { tableReadState = .failed(L10n.text("Free AI limit reached. Upgrade to Tempo Pro for unlimited reads.")); return }
        tableReadState = .loading
        let context = standings.prefix(10).map { "\($0.position). \($0.team.name): \($0.points) points, \($0.won)-\($0.drawn)-\($0.lost), form \($0.form ?? "unavailable")" }.joined(separator: "\n")
        let fixtures = (try? await service.leagueFixtures(league.id)) ?? []
        let upcoming = fixtures.filter { ($0.kickoff ?? .distantPast) > Date() }.sorted { ($0.kickoff ?? .distantFuture) < ($1.kickoff ?? .distantFuture) }.prefix(6)
            .map { "\($0.homeTeam.name) vs \($0.awayTeam.name) at \($0.kickoff?.formatted(date: .abbreviated, time: .shortened) ?? "time unavailable")" }.joined(separator: "\n")
        do {
            tableRead = try await gemini.answer(
                question: "Give a concise table read based only on these standings, computed recent form, and upcoming fixtures. Do not invent statistics or predictions.",
                context: "League: \(league.name)\nSeason: \(league.season ?? "unavailable")\nReal standings:\n\(context)\nUpcoming fixtures:\n\(upcoming.isEmpty ? "Unavailable" : upcoming)"
            )
            UsageMetricsService.shared.recordAIRead()
            _ = EntitlementService.shared.consumeAIRequest()
            tableReadState = .loaded
        } catch NetworkError.offline { tableReadState = .offline }
        catch { tableReadState = .failed(error.localizedDescription) }
    }
    private func recentForm(from results: [Fixture]) -> [String: String] {
        var values: [String: [String]] = [:]
        let completed = results.filter { $0.homeScore != nil && $0.awayScore != nil }
            .sorted { ($0.kickoff ?? .distantPast) > ($1.kickoff ?? .distantPast) }
        for fixture in completed {
            guard let home = fixture.homeScore, let away = fixture.awayScore else { continue }
            if values[fixture.homeTeam.id, default: []].count < 5 {
                values[fixture.homeTeam.id, default: []].append(home == away ? "D" : home > away ? "W" : "L")
            }
            if values[fixture.awayTeam.id, default: []].count < 5 {
                values[fixture.awayTeam.id, default: []].append(home == away ? "D" : away > home ? "W" : "L")
            }
        }
        return values.mapValues { $0.joined() }
    }
    func loadTeam(_ selected: Team?, force: Bool = false) async {
        guard let selected else { teamState = .empty; return }
        if !force, team?.id == selected.id, teamState == .loaded { return }
        teamState = .loading
        do { async let details = service.team(selected.id); async let players = service.teamPlayers(selected.id); async let upcoming = service.teamFixtures(selected.id); async let results = service.teamResults(selected.id); async let metrics = service.teamStatistics(selected.id); team = try await details; squad = (try? await players) ?? []; fixtures = (try? await upcoming) ?? []; teamResults = (try? await results) ?? []; teamMetrics = (try? await metrics) ?? []; isFollowing = UserDefaults.standard.stringArray(forKey: "followedTeamNames")?.contains(selected.name) == true; if isFollowing, Set(UserDefaults.standard.stringArray(forKey: "enabledAlerts") ?? []).contains(AlertKind.startingSoon.rawValue) { for fixture in fixtures.prefix(10) { try? await NotificationService.shared.scheduleStartingSoon(for: fixture) } }; teamState = .loaded }
        catch NetworkError.offline { teamState = .offline } catch { teamState = .failed(error.localizedDescription) }
    }
    func toggleFollow() {
        guard let team else { return }
        var names = Set(UserDefaults.standard.stringArray(forKey: "followedTeamNames") ?? [])
        followMessage = nil
        if names.contains(team.name) { names.remove(team.name) }
        else {
            guard EntitlementService.shared.canFollow(teamCount: names.count) else {
                followMessage = L10n.text("The Free plan supports up to 5 followed teams. Tempo Pro removes this limit.")
                return
            }
            names.insert(team.name)
        }
        UserDefaults.standard.set(Array(names), forKey: "followedTeamNames")
        isFollowing = names.contains(team.name)
    }
}
