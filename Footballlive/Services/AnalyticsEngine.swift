import Foundation

enum AnalyticsEngine {
    static func momentum(events: [MatchEvent], statistics: [MatchStatistic], homeTeamID: String, currentMinute: Int = 90) -> [MomentumPoint] {
        let end = max(15, currentMinute)
        return stride(from: max(0, end - 45), through: end, by: 5).enumerated().map { index, minute in
            let recent = events.filter { ($0.minute ?? -100) > minute - 10 && ($0.minute ?? 1000) <= minute }
            var score = 0.0
            for event in recent {
                let weight: Double = event.type.lowercased().contains("goal") ? 4 : event.type.lowercased().contains("card") ? 1 : 1.5
                score += event.teamId == homeTeamID ? weight : -weight
            }
            if let shots = statistics.first(where: { $0.name.localizedCaseInsensitiveContains("shots on goal") || $0.name.localizedCaseInsensitiveContains("shots on target") }) { score += ((shots.home ?? 0) - (shots.away ?? 0)) * 0.25 }
            return MomentumPoint(id: index, minute: minute, value: min(10, max(-10, score)))
        }
    }

    static func excitement(fixture: Fixture, events: [MatchEvent], statistics: [MatchStatistic], momentum: [MomentumPoint], followsTeam: Bool) -> Double {
        let minute = Double(fixture.elapsed ?? 0)
        let difference = abs((fixture.homeScore ?? 0) - (fixture.awayScore ?? 0))
        let recentGoals = events.filter { $0.type.lowercased().contains("goal") && ($0.minute ?? 0) >= Int(minute) - 10 }.count
        let cards = events.filter { $0.type.lowercased().contains("card") }.count
        let surge = momentum.suffix(3).map { abs($0.value) }.max() ?? 0
        var value = 2 + min(minute / 30, 3) + (difference <= 1 ? 1.5 : 0) + Double(recentGoals) * 1.2 + Double(cards) * 0.15 + surge * 0.2 + (followsTeam ? 0.5 : 0)
        if fixture.status == .fullTime { value -= 1 }
        return min(10, max(0, value))
    }
}
