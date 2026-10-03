import Foundation
import SwiftData

enum NavItem: String, CaseIterable {
    case live = "Live Scores", match = "Match Center", highlights = "Highlights", leagues = "Leagues", teams = "Teams"
    case commentator = "Co-Commentator", follow = "Follow Setup", alerts = "Alerts & Profile", settings = "Settings", pro = "Tempo Pro"
    static var sections: [(String, [NavItem])] {
        let discovery: [NavItem] = APIConfiguration.allowsHighlightPlayback ? [.highlights, .leagues, .teams] : [.leagues, .teams]
        return [("Live", [.live, .match]), ("Discover", discovery), ("Intelligence", [.commentator]), ("Account", [.follow, .alerts, .settings, .pro])]
    }
    var header: (title: String, subtitle: String) {
        switch self {
        case .live: return (rawValue, "Today · All competitions")
        case .match: return (rawValue, "Real match data")
        case .highlights: return (rawValue, "Recent GOAL API videos")
        case .leagues: return (rawValue, "Standings and competition data")
        case .teams: return (rawValue, "Club profile")
        case .commentator: return ("AI Co-Commentator", "Grounded in current match data")
        case .follow: return ("Set up your feed", "Choose teams and alerts")
        case .alerts: return (rawValue, "Smart notifications")
        case .settings: return (rawValue, "Appearance, language, account and legal")
        case .pro: return (rawValue, "Plans & billing")
        }
    }
}

enum LoadState: Equatable { case idle, loading, loaded, empty, offline, failed(String) }

struct Team: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var badgeURL: URL?
    var country: String?
    var founded: String?
    var leagueName: String?
}

struct League: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var countryName: String?
    var logoURL: URL?
    var season: String?
    var popularity: Int? = nil
    var isActive: Bool? = nil
}

enum MatchStatus: String, Codable { case live = "LIVE", halfTime = "HT", fullTime = "FT", scheduled = "SCHEDULED", postponed = "POSTPONED", cancelled = "CANCELLED", unknown = "UNKNOWN" }

struct Fixture: Identifiable, Codable, Hashable {
    let id: String
    var league: League
    var homeTeam: Team
    var awayTeam: Team
    var homeScore: Int?
    var awayScore: Int?
    var status: MatchStatus
    var elapsed: Int?
    var kickoff: Date?
    var venue: String?
    var isFavorite = false
    var displayStatus: String {
        if status == .live, let elapsed { return "\(elapsed)'" }
        return status.rawValue
    }
    var isLive: Bool { status == .live || status == .halfTime }
}

struct LeagueGroup: Identifiable { var id: String { league.id }; let league: League; var matches: [Fixture]; var name: String { league.name }; var country: String { league.countryName ?? "" } }
struct MatchStatistic: Identifiable, Codable, Hashable { var id: String { name }; let name: String; let home: Double?; let away: Double?; var formatted: String { home.map { Self.format($0) } ?? "Not available" }; nonisolated static func format(_ n: Double) -> String { n.rounded() == n ? String(Int(n)) : String(format: "%.1f", n) } }
struct MatchEvent: Identifiable, Codable, Hashable { let id: String; var minute: Int?; var type: String; var detail: String?; var teamId: String?; var teamName: String?; var playerName: String?; var assistName: String? }
struct MatchLineup: Identifiable, Codable, Hashable { let id: String; var team: Team; var formation: String?; var starters: [Player]; var substitutes: [Player] }
struct Player: Identifiable, Codable, Hashable { let id: String; var name: String; var number: String?; var position: String?; var photoURL: URL?; var goals: Int?; var assists: Int? }
struct Standing: Identifiable, Codable, Hashable { var id: String { "\(team.id)-\(position)" }; var position: Int; var team: Team; var played: Int; var won: Int; var drawn: Int; var lost: Int; var goalsFor: Int?; var goalsAgainst: Int?; var goalDifference: Int; var points: Int; var form: String? }
struct TopScorer: Identifiable, Hashable { let id: String; var playerName: String; var teamName: String?; var photoURL: URL?; var goals: Int; var assists: Int? }
struct TeamMetric: Identifiable, Hashable { var id: String { name }; let name: String; let value: String }
struct Highlight: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var competition: String?
    var category: String?
    var thumbnailURL: URL?
    var videoURL: URL?
    var embedURL: URL?
    var duration: String?
    var fixtureId: String?
    var publishedAt: String?
    var sourceName: String?

    var playableURL: URL? { videoURL ?? embedURL }
}
struct NewsArticle: Identifiable, Codable, Hashable { let id: String; var title: String; var summary: String?; var url: URL?; var publishedAt: Date?; var imageURL: URL? }
struct MomentumPoint: Identifiable, Codable, Hashable { let id: Int; let minute: Int; let value: Double }
struct CommentaryItem: Identifiable { let id = UUID(); let time: String, title: String, text: String }
struct WinProbability { let home: Double, draw: Double, away: Double; let swing: String }
struct StatItem: Identifiable { let id = UUID(); let label: String, value: String }
struct TimelineEvent: Identifiable { enum Kind { case goalHome, goalAway, yellow, red, substitution, other }; let id = UUID(); let time: String, kind: Kind, title: String, detail: String }
struct LiveTip: Identifiable { let id = UUID(); let tag: String, time: String, text: String, colorHex: String }
struct ChatMessage: Identifiable, Codable { let id: UUID; let isUser: Bool; let text: [String]; var stats: [String: String]; init(id: UUID = UUID(), isUser: Bool, text: [String], stats: [String: String] = [:]) { self.id = id; self.isUser = isUser; self.text = text; self.stats = stats } }
struct TeamOption: Identifiable { let id: String; let code: String; let name: String; let colorHex: String; let badgeURL: URL? }

enum AlertKind: String, CaseIterable, Identifiable, Codable {
    case goals, surge, everyGoal, startingSoon, news, recap
    var id: String { rawValue }
    var info: (title: String, subtitle: String) {
        switch self {
        case .goals: return ("Goals for followed teams", "While the app is running and receiving live-score updates")
        case .surge: return ("Momentum surge", "While an open match is refreshed and crosses your threshold")
        case .everyGoal: return ("Every goal, every league", "Requires a backend for reliable background delivery")
        case .startingSoon: return ("Match starting soon", "Schedules reminders after upcoming fixtures are loaded")
        case .news: return ("Transfer & injury news", "Unavailable until a backend classifies and pushes confirmed reports")
        case .recap: return ("Weekly reminder", "Schedules a weekly reminder to open Football Live")
        }
    }
    var clientAvailable: Bool { self != .everyGoal && self != .news }
}

@Model final class FollowedTeam {
    @Attribute(.unique) var teamID: String
    var name: String
    var badgeURLString: String?
    init(teamID: String, name: String, badgeURLString: String? = nil) { self.teamID = teamID; self.name = name; self.badgeURLString = badgeURLString }
}

@Model final class UserPreferences {
    @Attribute(.unique) var key = "primary"
    var excitementThreshold = 6.4
    var enabledAlertIDs = "goals,surge,startingSoon,recap"
    var setupCompleted = false
    init() {}
}

struct SettingRow: Identifiable { let id = UUID(); let code: String, title: String, subtitle: String, value: String }
struct PlanInfo: Identifiable { let id: String; let name: String, price: String, unit: String, note: String, noteColorHex: String; let features: [String], button: String; let isFeatured: Bool }
