import SwiftUI

struct LiveScoresView: View {
    @EnvironmentObject var vm: LiveScoresViewModel
    @EnvironmentObject var app: AppViewModel
    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading: ScreenStateView(title: "Loading live scores…", systemImage: "clock")
            case .empty: ScreenStateView(title: "No live matches right now.", subtitle: "Check back soon or retry to refresh live data.", systemImage: "sportscourt") { Task { await vm.load(force: true) } }
            case .offline: ScreenStateView(title: "You're offline.", subtitle: "Check your internet connection.", systemImage: "wifi.slash") { Task { await vm.load(force: true) } }
            case .failed(let message): ScreenStateView(title: "Unable to load scores.", subtitle: message, systemImage: "exclamationmark.triangle") { Task { await vm.load(force: true) } }
            case .loaded: scores
            }
        }.task {
            // A cached response can complete synchronously. Start after SwiftUI's
            // current reconciliation pass to avoid publishing during view updates.
            try? await Task.sleep(for: .milliseconds(1))
            guard !Task.isCancelled else { return }
            await vm.load(force: true)
            app.liveCount = vm.leagues.flatMap(\.matches).filter(\.isLive).count
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
                await vm.load(force: true)
                app.liveCount = vm.leagues.flatMap(\.matches).filter(\.isLive).count
            }
        }
    }
    private var scores: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                LazyVStack(spacing: 18) { ForEach(vm.leagues) { LeagueMatchSection(league: $0) } }
                VStack(spacing: 14) {
                    LiveCommentaryPanel(fixture: vm.featuredFixture, items: vm.commentary)
                }.frame(width: 270)
            }.padding(20)
        }.refreshable { await vm.load(force: true) }
    }
}

struct LiveCommentaryPanel: View {
    let fixture: Fixture?
    let items: [CommentaryItem]
    var body: some View {
        Card(highlight: true) {
            VStack(alignment: .leading, spacing: 10) {
                Mono(text: "Live commentary", color: AppColors.lime)
                if let fixture {
                    Text("\(fixture.homeTeam.name) vs \(fixture.awayTeam.name)")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.text)
                    if items.isEmpty {
                        Text("Commentary is not available for this match.").font(.system(size: 10)).foregroundColor(AppColors.muted)
                    } else {
                        ForEach(items.prefix(5)) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                if !item.time.isEmpty { Mono(text: item.time, size: 7, color: AppColors.lime) }
                                Text(item.text).font(.system(size: 10)).foregroundColor(AppColors.text).lineLimit(4)
                            }
                            if item.id != items.prefix(5).last?.id { Divider().overlay(AppColors.border) }
                        }
                    }
                } else {
                    Text("No live match selected.").font(.system(size: 10)).foregroundColor(AppColors.muted)
                }
            }
        }
    }
}

struct LeagueMatchSection: View {
    @EnvironmentObject var vm: LiveScoresViewModel
    @EnvironmentObject var app: AppViewModel
    let league: LeagueGroup
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Mono(text: league.name, size: 8); Spacer(); Mono(text: league.country, size: 8) }
            Divided { ForEach(league.matches) { fixture in MatchRowView(fixture: fixture, onOpen: { app.open(fixture: fixture) }, onStar: { vm.toggleStar(fixture) }); if fixture.id != league.matches.last?.id { Divider().overlay(AppColors.border) } } }
        }
    }
}

struct MatchRowView: View {
    @EnvironmentObject var account: AccountViewModel
    let fixture: Fixture; var onOpen: () -> Void; var onStar: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) { Circle().fill(fixture.isLive ? AppColors.red : AppColors.muted).frame(width: 4, height: 4); Text(fixture.displayStatus).font(.system(size: 10, design: .monospaced)).foregroundColor(fixture.isLive ? AppColors.red : AppColors.muted) }.frame(width: 66, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) { team(fixture.homeTeam); team(fixture.awayTeam) }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) { Text(fixture.homeScore.map(String.init) ?? "–"); Text(fixture.awayScore.map(String.init) ?? "–") }.font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(AppColors.text)
            Button(action: onStar) { Image(systemName: fixture.isFavorite ? "star.fill" : "star").font(.system(size: 11)).foregroundColor(fixture.isFavorite ? AppColors.lime : AppColors.muted) }.buttonStyle(.plain).padding(.leading, 12)
        }.padding(.horizontal, 16).padding(.vertical, account.compactRows ? 7 : 12).contentShape(Rectangle()).onTapGesture(perform: onOpen)
    }
    private func team(_ team: Team) -> some View { HStack(spacing: 8) { RemoteBadge(url: team.badgeURL, name: team.name, size: 20); Text(team.name).font(.system(size: 12, weight: .semibold)).lineLimit(1) }.foregroundColor(AppColors.text) }
}
