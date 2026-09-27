import Foundation

private nonisolated enum JSONValue: Decodable {
    case object([String: JSONValue]), array([JSONValue]), string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value") }
    }
    var object: [String: JSONValue]? { if case .object(let v) = self { v } else { nil } }
    var array: [JSONValue]? { if case .array(let v) = self { v } else { nil } }
    var string: String? { switch self { case .string(let v): v; case .number(let v): String(v); default: nil } }
    var int: Int? {
        guard let text = string?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty,
              let value = Double(text),
              value.isFinite else { return nil }
        return Int(value)
    }
    var double: Double? { string.flatMap(Double.init) }
    var bool: Bool? { if case .bool(let value) = self { value } else { string.flatMap(Bool.init) } }
    var url: URL? { string.flatMap(URL.init(string:)) }
}

/// Serializes networking/decoding away from the main actor so large football
/// payloads can never block SwiftUI rendering or input handling.
actor GoalAPIService {
    static let shared = GoalAPIService()
    private let network = NetworkService()
    private let decoder = JSONDecoder()
    private let dateFormatter = ISO8601DateFormatter()

    private func root(_ endpoint: GoalEndpoint, cacheFor: TimeInterval) async throws -> JSONValue {
        let baseURL: URL
        let pathPrefix: String
        if let backend = APIConfiguration.backendBaseURL {
            baseURL = backend
            pathPrefix = backend.path + "/v1/goal"
        } else {
            baseURL = APIConfiguration.goalBaseURL
            pathPrefix = APIConfiguration.goalBaseURL.path
        }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = pathPrefix + endpoint.path
        if !endpoint.query.isEmpty { components.queryItems = endpoint.query }
        var request = URLRequest(url: components.url!)
        if APIConfiguration.backendBaseURL == nil {
            guard let key = APIConfiguration.goalAPIKey else { throw NetworkError.missingConfiguration("GOAL_API_KEY") }
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data = try await network.data(for: request, cacheFor: cacheFor)
        do {
            let envelope = try decoder.decode(JSONValue.self, from: data)
            guard let data = envelope.object?["data"] else { throw NetworkError.invalidResponse }
            return data
        } catch let error as NetworkError { throw error }
        catch { throw NetworkError.decoding(error.localizedDescription) }
    }

    func liveFixtures() async throws -> [Fixture] { try await fixtureList(.liveFixtures, ttl: 30) }
    func fixturesToday() async throws -> [Fixture] {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"
        return try await fixtureList(.fixtures(date: formatter.string(from: Date())), ttl: 120)
    }
    func fixture(id: String) async throws -> Fixture { guard let item = try await root(.fixture(id), cacheFor: 30).object else { throw NetworkError.invalidResponse }; return parseFixture(item) }
    func events(id: String) async throws -> [MatchEvent] { try await array(.events(id), ttl: 30).enumerated().map(parseEvent) }
    func cards(id: String) async throws -> [MatchEvent] { try await array(.cards(id), ttl: 30).enumerated().map(parseEvent) }
    func substitutions(id: String) async throws -> [MatchEvent] { try await array(.substitutions(id), ttl: 30).enumerated().map(parseEvent) }
    func statistics(id: String) async throws -> [MatchStatistic] {
        let value = try await root(.statistics(id), cacheFor: 30)
        let rows = value.object?["match"]?.object?["fullTime"]?.array ?? []
        return rows.compactMap { row in guard let o = row.object, let name = o["type"]?.string else { return nil }; return MatchStatistic(name: name, home: number(o["home"]), away: number(o["away"])) }
    }
    func commentary(id: String) async throws -> [CommentaryItem] {
        try await array(.commentary(id), ttl: 30).compactMap { value in guard let o = value.object, let text = o["text"]?.string else { return nil }; return CommentaryItem(time: o["time"]?.string ?? "", title: "Live commentary", text: text) }
    }
    func lineups(id: String, fixture: Fixture) async throws -> [MatchLineup] {
        let o = try await root(.lineups(id), cacheFor: 300).object ?? [:]
        func side(_ key: String, team: Team) -> MatchLineup {
            let data = o[key]?.object ?? [:]
            return MatchLineup(id: team.id, team: team, formation: o["\(key)Formation"]?.string, starters: players(data["startingLineups"]?.array), substitutes: players(data["substitutes"]?.array))
        }
        return [side("home", team: fixture.homeTeam), side("away", team: fixture.awayTeam)]
    }
    func leagues() async throws -> [League] { try await array(.leagues, ttl: 3600).compactMap { $0.object.map(parseLeague) } }
    func standings(leagueID: String) async throws -> [Standing] { try await array(.leagueStandings(leagueID), ttl: 300).compactMap(parseStanding) }
    func leagueFixtures(_ id: String) async throws -> [Fixture] { try await fixtureList(.leagueFixtures(id), ttl: 300) }
    func leagueResults(_ id: String) async throws -> [Fixture] { try await fixtureList(.leagueResults(id), ttl: 300) }
    func topScorers(_ id: String) async throws -> [TopScorer] {
        try await array(.topScorers(id), ttl: 300).enumerated().compactMap { index, value in
            guard let o = value.object else { return nil }
            let player = o["player"]?.object
            let team = o["team"]?.object
            let name = o["playerName"]?.string ?? o["name"]?.string ?? player?["name"]?.string
            guard let name else { return nil }
            return TopScorer(id: o["id"]?.string ?? player?["id"]?.string ?? "\(id)-\(index)", playerName: name, teamName: o["teamName"]?.string ?? team?["name"]?.string, photoURL: o["photo"]?.url ?? o["image"]?.url ?? player?["photo"]?.url, goals: o["goals"]?.int ?? o["totalGoals"]?.int ?? 0, assists: o["assists"]?.int)
        }
    }
    func teams(search: String? = nil) async throws -> [Team] { try await array(.teams(search: search), ttl: 3600).compactMap { $0.object.map(parseTeam) } }
    func leagueTeams(_ id: String) async throws -> [Team] { try await array(.leagueTeams(id), ttl: 1800).compactMap { $0.object.map(parseTeam) } }
    func team(_ id: String) async throws -> Team { guard let o = try await root(.team(id), cacheFor: 600).object else { throw NetworkError.invalidResponse }; return parseTeam(o) }
    func teamPlayers(_ id: String) async throws -> [Player] { players(try await array(.teamPlayers(id), ttl: 600)) }
    func teamFixtures(_ id: String) async throws -> [Fixture] { try await fixtureList(.teamUpcoming(id), ttl: 300) }
    func teamResults(_ id: String) async throws -> [Fixture] { try await fixtureList(.teamResults(id), ttl: 300) }
    func teamStatistics(_ id: String) async throws -> [TeamMetric] {
        let value = try await root(.teamStatistics(id), cacheFor: 300)
        let object = value.object ?? [:]
        return object.keys.sorted().compactMap { key in
            guard let raw = object[key]?.string, !raw.isEmpty else { return nil }
            return TeamMetric(name: key.replacingOccurrences(of: "_", with: " ").capitalized, value: raw)
        }
    }
    func highlights() async throws -> [Highlight] { try await array(.recentVideos, ttl: 300).compactMap(parseHighlight) }

    private func array(_ endpoint: GoalEndpoint, ttl: TimeInterval) async throws -> [JSONValue] { try await root(endpoint, cacheFor: ttl).array ?? [] }
    private func fixtureList(_ endpoint: GoalEndpoint, ttl: TimeInterval) async throws -> [Fixture] { try await array(endpoint, ttl: ttl).compactMap { $0.object.map(parseFixture) } }
    private func parseFixture(_ o: [String: JSONValue]) -> Fixture {
        let league = League(id: o["leagueId"]?.string ?? "unknown", name: o["leagueName"]?.string ?? "Unknown competition", countryName: o["countryName"]?.string, logoURL: o["leagueLogo"]?.url, season: o["leagueYear"]?.string ?? o["season"]?.string)
        let home = Team(id: o["homeTeamId"]?.string ?? "home", name: o["homeTeamName"]?.string ?? "Home", badgeURL: o["homeTeamBadge"]?.url ?? o["teamHomeBadge"]?.url)
        let away = Team(id: o["awayTeamId"]?.string ?? "away", name: o["awayTeamName"]?.string ?? "Away", badgeURL: o["awayTeamBadge"]?.url ?? o["teamAwayBadge"]?.url)
        let raw = o["matchStatus"]?.string?.uppercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_")
            ?? (o["matchLive"]?.int == 1 ? "LIVE" : "UNKNOWN")
        let status: MatchStatus
        if raw == "HT" || raw == "HALF_TIME" || raw == "HALFTIME" {
            status = .halfTime
        } else if raw.contains("LIVE") || o["matchLive"]?.int == 1 {
            status = .live
        } else if raw.contains("FINISH") || raw == "FT" {
            status = .fullTime
        } else if raw.contains("SCHED") || raw == "NS" {
            status = .scheduled
        } else if raw.contains("POST") {
            status = .postponed
        } else if raw.contains("CANCEL") {
            status = .cancelled
        } else {
            status = .unknown
        }
        return Fixture(id: o["id"]?.string ?? UUID().uuidString, league: league, homeTeam: home, awayTeam: away, homeScore: o["homeTeamScore"]?.int, awayScore: o["awayTeamScore"]?.int, status: status, elapsed: o["matchElapsed"]?.int ?? o["matchMinute"]?.int, kickoff: o["kickoffUtc"]?.string.flatMap(dateFormatter.date), venue: o["matchStadium"]?.string)
    }
    private func parseLeague(_ o: [String: JSONValue]) -> League { League(id: o["id"]?.string ?? UUID().uuidString, name: o["name"]?.string ?? "Unknown", countryName: o["countryName"]?.string ?? o["country"]?.string, logoURL: o["logo"]?.url, season: o["season"]?.string, popularity: o["popularity"]?.int, isActive: o["isActive"]?.bool) }
    private func parseTeam(_ o: [String: JSONValue]) -> Team { Team(id: o["id"]?.string ?? UUID().uuidString, name: o["name"]?.string ?? "Unknown", badgeURL: o["badge"]?.url, country: o["country"]?.string, founded: o["founded"]?.string) }
    private func parseStanding(_ value: JSONValue) -> Standing? {
        guard let o = value.object, let teamID = o["teamId"]?.string, let name = o["teamName"]?.string else { return nil }
        let gf = o["overallLeagueGF"]?.int, ga = o["overallLeagueGA"]?.int
        return Standing(position: o["overallLeaguePosition"]?.int ?? 0, team: Team(id: teamID, name: name, badgeURL: o["teamBadge"]?.url), played: o["overallLeaguePlayed"]?.int ?? 0, won: o["overallLeagueW"]?.int ?? 0, drawn: o["overallLeagueD"]?.int ?? 0, lost: o["overallLeagueL"]?.int ?? 0, goalsFor: gf, goalsAgainst: ga, goalDifference: (gf ?? 0) - (ga ?? 0), points: o["overallLeaguePTS"]?.int ?? 0, form: o["form"]?.string)
    }
    private func parseEvent(_ pair: (offset: Int, element: JSONValue)) -> MatchEvent {
        let o = pair.element.object ?? [:]
        return MatchEvent(id: "\(o["time"]?.string ?? "")-\(pair.offset)", minute: o["time"]?.int, type: o["type"]?.string ?? "Event", detail: o["info"]?.string ?? o["score"]?.string, teamId: nil, teamName: nil, playerName: o["homeScorer"]?.string ?? o["awayScorer"]?.string, assistName: o["homeAssist"]?.string ?? o["awayAssist"]?.string)
    }
    private func parseHighlight(_ value: JSONValue) -> Highlight? {
        guard let o = value.object, let id = o["id"]?.string ?? o["videoId"]?.string else { return nil }
        let url = firstURL(in: o, keys: ["url", "videoUrl", "videoURL", "embedUrl", "embedURL"])
        let direct = ["mp4", "m3u8", "mov"].contains(url?.pathExtension.lowercased() ?? "")
        return Highlight(
            id: id,
            title: o["titleFull"]?.string ?? o["title"]?.string ?? "Highlight",
            competition: o["leagueName"]?.string ?? o["competitionName"]?.string ?? o["competition"]?.string,
            category: o["category"]?.string ?? o["type"]?.string,
            thumbnailURL: firstURL(in: o, keys: ["thumbnailUrl", "thumbnailURL", "thumbnail", "imageUrl", "imageURL", "image"]),
            videoURL: direct ? url : nil,
            embedURL: direct ? nil : url,
            duration: o["duration"]?.string ?? o["videoDuration"]?.string,
            fixtureId: o["fixtureId"]?.string ?? o["matchId"]?.string,
            publishedAt: o["publishedAt"]?.string ?? o["date"]?.string,
            sourceName: o["source"]?.string ?? o["provider"]?.string
        )
    }
    private func firstURL(in object: [String: JSONValue], keys: [String]) -> URL? {
        keys.lazy.compactMap { object[$0]?.url }.first
    }
    private func players(_ values: [JSONValue]?) -> [Player] { (values ?? []).compactMap { value in guard let o = value.object else { return nil }; return Player(id: o["id"]?.string ?? o["playerId"]?.string ?? UUID().uuidString, name: o["name"]?.string ?? o["playerName"]?.string ?? "Unknown", number: o["number"]?.string ?? o["playerNumber"]?.string, position: o["type"]?.string ?? o["position"]?.string, photoURL: o["image"]?.url, goals: o["goals"]?.int, assists: o["assists"]?.int) } }
    private func number(_ value: JSONValue?) -> Double? {
        guard let text = value?.string else { return nil }
        return Double(text.replacingOccurrences(of: "%", with: ""))
    }
}
