import SwiftUI
import Charts

struct MatchCenterView: View {
    @EnvironmentObject var vm: MatchCenterViewModel
    @EnvironmentObject var app: AppViewModel
    var body: some View {
        Group {
            switch vm.state {
            case .idle where app.selectedFixture == nil, .empty where app.selectedFixture == nil: ScreenStateView(title: "Select a match from Live Scores.", systemImage: "sportscourt") { app.open(.live) }
            case .loading: ScreenStateView(title: "Loading match center…", systemImage: "clock")
            case .offline: ScreenStateView(title: "You're offline.", subtitle: "Check your internet connection.", systemImage: "wifi.slash") { Task { await vm.load(app.selectedFixture, force: true) } }
            case .failed(let message): ScreenStateView(title: "Unable to load match.", subtitle: message, systemImage: "exclamationmark.triangle") { Task { await vm.load(app.selectedFixture, force: true) } }
            default: content
            }
        }.task(id: app.selectedFixture?.id) { await vm.load(app.selectedFixture) }
    }
    private var content: some View {
        ScrollView { VStack(spacing: 0) { if let fixture = vm.fixture { MatchHeaderView(fixture: fixture) }; HStack(alignment: .top, spacing: 16) { VStack(spacing: 14) { MomentumPulseView(values: vm.momentum); MatchStatisticsView(statistics: vm.statistics); MatchTimelineView(events: vm.timeline); MatchLineupsView(lineups: vm.lineups) }; MatchAIPanel(items: vm.commentary, excitement: vm.excitement).frame(width: 280) }.padding(20) } }
    }
}

struct MatchLineupsView: View {
    let lineups: [MatchLineup]
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lineups").font(.system(size: 12, weight: .semibold))
                if lineups.allSatisfy({ $0.starters.isEmpty && $0.substitutes.isEmpty }) {
                    Text("Lineups have not been published by the data provider.").foregroundColor(AppColors.muted)
                } else {
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(lineups) { lineup in
                            VStack(alignment: .leading, spacing: 7) {
                                HStack { RemoteBadge(url: lineup.team.badgeURL, name: lineup.team.name, size: 20); Text(lineup.team.name).fontWeight(.semibold); Spacer(); Text(lineup.formation ?? "").foregroundColor(AppColors.muted) }
                                Mono(text: "Starting XI", size: 7)
                                ForEach(lineup.starters) { player in Text("\(player.number ?? "–")  \(player.name)").lineLimit(1) }
                                if !lineup.substitutes.isEmpty { Mono(text: "Substitutes", size: 7).padding(.top, 4) }
                                ForEach(lineup.substitutes) { player in Text("\(player.number ?? "–")  \(player.name)").lineLimit(1).foregroundColor(AppColors.muted) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }.font(.system(size: 10))
        }
    }
}

struct MatchHeaderView: View {
    let fixture: Fixture
    var body: some View { VStack(spacing: 8) { HStack(spacing: 22) { team(fixture.homeTeam, alignment: .trailing); Text("\(fixture.homeScore.map(String.init) ?? "–") : \(fixture.awayScore.map(String.init) ?? "–")").font(.system(size: 30, weight: .bold, design: .monospaced)); team(fixture.awayTeam, alignment: .leading) }.foregroundColor(AppColors.text); Text(fixture.displayStatus).font(.system(size: 9, design: .monospaced)).foregroundColor(fixture.isLive ? AppColors.red : AppColors.muted).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(AppColors.red.opacity(0.12))) }.frame(maxWidth: .infinity).padding(.vertical, 26).background(LinearGradient(colors: [Color(hex: "1A1E24"), AppColors.bg], startPoint: .top, endPoint: .bottom)) }
    private func team(_ team: Team, alignment: HorizontalAlignment) -> some View { VStack(alignment: alignment, spacing: 5) { RemoteBadge(url: team.badgeURL, name: team.name, size: 32); Text(team.name).font(.system(size: 18, weight: .bold)) } }
}

struct MomentumPulseView: View {
    let values: [MomentumPoint]
    var body: some View { Card(highlight: true) { VStack(alignment: .leading, spacing: 8) { HStack { Text("Momentum Pulse").font(.system(size: 12, weight: .semibold)); Spacer(); Mono(text: "Calculated from available real events", size: 7) }; if values.isEmpty { Text("Not available").foregroundColor(AppColors.muted).frame(height: 120) } else { Chart(values) { point in BarMark(x: .value("Minute", point.minute), y: .value("Momentum", point.value), width: .ratio(0.7)).foregroundStyle(point.value >= 0 ? AppColors.lime.opacity(0.7) : AppColors.blue.opacity(0.8)) }.chartYAxis(.hidden).frame(height: 130) } } } }
}

struct MatchStatisticsView: View {
    let statistics: [MatchStatistic]
    var body: some View { Card { VStack(alignment: .leading, spacing: 12) { Text("Statistics").font(.system(size: 12, weight: .semibold)); if statistics.isEmpty { Text("Not available").foregroundColor(AppColors.muted) } else { ForEach(statistics) { stat in HStack { Text(stat.home.map(MatchStatistic.format) ?? "–").frame(width: 50); Text(stat.name).foregroundColor(AppColors.muted).frame(maxWidth: .infinity); Text(stat.away.map(MatchStatistic.format) ?? "–").frame(width: 50) }.font(.system(size: 11, design: .monospaced)) } } } } }
}

struct MatchTimelineView: View {
    let events: [TimelineEvent]
    func color(_ kind: TimelineEvent.Kind) -> Color { switch kind { case .goalHome, .substitution: AppColors.lime; case .goalAway: AppColors.blue; case .yellow: .yellow; case .red: .red; case .other: AppColors.muted } }
    var body: some View { Card { VStack(alignment: .leading, spacing: 12) { Text("Timeline").font(.system(size: 12, weight: .semibold)); if events.isEmpty { Text("No match events available.").foregroundColor(AppColors.muted) } else { ForEach(events) { event in HStack(alignment: .top, spacing: 10) { Text(event.time).font(.system(size: 10, design: .monospaced)).foregroundColor(AppColors.muted).frame(width: 32); Circle().fill(color(event.kind)).frame(width: 7, height: 7).padding(.top, 3); VStack(alignment: .leading) { Text(event.title).fontWeight(.semibold); Text(event.detail).foregroundColor(AppColors.muted) }.font(.system(size: 11)) } } } } } }
}

struct MatchAIPanel: View {
    let items: [CommentaryItem]; let excitement: Double
    var body: some View { VStack(spacing: 14) { Card(highlight: true) { VStack(alignment: .leading, spacing: 10) { Mono(text: "Excitement score", color: AppColors.lime); Text(String(format: "%.1f / 10", excitement)).font(.system(size: 24, weight: .bold)); Text("Calculated locally from available match data.").font(.system(size: 10)).foregroundColor(AppColors.muted) } }; Card { VStack(alignment: .leading, spacing: 10) { Mono(text: "Live commentary"); if items.isEmpty { Text("Not available").foregroundColor(AppColors.muted) } else { ForEach(items.prefix(8)) { item in Text("\(item.time)  \(item.text)").font(.system(size: 10)) } } } } } }
}
