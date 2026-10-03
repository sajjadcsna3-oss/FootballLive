import Foundation

nonisolated enum GoalEndpoint {
    case liveFixtures, fixtures(date: String?), fixture(String), events(String), cards(String), substitutions(String), lineups(String), statistics(String), commentary(String)
    case leagues, leagueStandings(String), leagueTeams(String), leagueFixtures(String), leagueResults(String), topScorers(String)
    case teams(search: String?), team(String), teamPlayers(String), teamFixtures(String), teamResults(String), teamStatistics(String), teamUpcoming(String)
    case videos, recentVideos, matchVideos(String), leagueVideos(String), videosByDate(String), news
    var path: String {
        switch self {
        case .liveFixtures: return "/fixtures/live"
        case .fixtures(let date): return date.map { "/fixtures/date/\($0)" } ?? "/fixtures"
        case .fixture(let id): return "/fixtures/\(id)"
        case .events(let id): return "/fixtures/\(id)/events"
        case .cards(let id): return "/fixtures/\(id)/cards"
        case .substitutions(let id): return "/fixtures/\(id)/substitutions"
        case .lineups(let id): return "/fixtures/\(id)/lineups"
        case .statistics(let id): return "/fixtures/\(id)/statistics"
        case .commentary(let id): return "/fixtures/\(id)/commentary"
        case .leagues: return "/leagues"
        case .leagueStandings(let id): return "/leagues/\(id)/standings"
        case .leagueTeams(let id): return "/leagues/\(id)/teams"
        case .leagueFixtures(let id): return "/leagues/\(id)/fixtures"
        case .leagueResults(let id): return "/leagues/\(id)/results"
        case .topScorers(let id): return "/leagues/\(id)/top-scorers"
        case .teams: return "/teams"
        case .team(let id): return "/teams/\(id)"
        case .teamPlayers(let id): return "/teams/\(id)/players"
        case .teamFixtures(let id): return "/teams/\(id)/fixtures"
        case .teamResults(let id): return "/teams/\(id)/results"
        case .teamStatistics(let id): return "/teams/\(id)/statistics"
        case .teamUpcoming(let id): return "/teams/\(id)/upcoming"
        case .videos: return "/videos"
        case .recentVideos: return "/videos/recent"
        case .matchVideos(let id): return "/videos/match/\(id)"
        case .leagueVideos(let id): return "/videos/league/\(id)"
        case .videosByDate(let date): return "/videos/date/\(date)"
        case .news: return "/news"
        }
    }
    var query: [URLQueryItem] {
        switch self { case .teams(let search): return search.map { [URLQueryItem(name: "search", value: $0), URLQueryItem(name: "limit", value: "100")] } ?? [URLQueryItem(name: "limit", value: "100")]; case .leagues: return [URLQueryItem(name: "limit", value: "100")]; default: return [] }
    }
}
