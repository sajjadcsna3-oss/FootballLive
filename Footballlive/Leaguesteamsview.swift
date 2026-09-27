import SwiftUI

struct LeaguesView: View {
    @EnvironmentObject var vm: LeaguesTeamsViewModel
    @EnvironmentObject var app: AppViewModel
    var body: some View {
        Group {
            if vm.leagues.isEmpty {
                switch vm.leagueState {
                case .idle, .loading: ScreenStateView(title: "Loading competitions…", systemImage: "list.number")
                case .offline: ScreenStateView(title: "You're offline.", systemImage: "wifi.slash") { Task { await vm.loadLeagues(force: true) } }
                case .failed(let message): ScreenStateView(title: "Unable to load competitions.", subtitle: message) { Task { await vm.loadLeagues(force: true) } }
                default: ScreenStateView(title: "No competitions are available.", systemImage: "list.number") { Task { await vm.loadLeagues(force: true) } }
                }
            } else { content }
        }
        .task { await vm.loadLeagues(); app.selectedLeague = vm.selectedLeague }
        .onChange(of: vm.selectedLeague) { _, league in app.selectedLeague = league }
    }
    private var content: some View {
        HStack(alignment: .top, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("League section", selection: $vm.leagueTab) {
                        ForEach(LeaguesTeamsViewModel.LeagueTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    Card {
                        VStack(spacing: 0) {
                            if vm.leagueTab == .standings { tableHeader }
                            switch vm.leagueState {
                            case .loading: ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(40)
                            case .offline: tableMessage("You're offline. Check your connection.")
                            case .failed(let message): tableMessage(message)
                            case .empty: tableMessage("No standings are available for this competition and season.")
                            default: leagueSection
                            }
                        }
                    }.padding(0)
                }.padding(.leading, 20).padding(.vertical, 20)
            }
            VStack(spacing: 14) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Mono(text: "Competitions", size: 8)
                        Divider().overlay(AppColors.border)
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(vm.leagues) { league in competitionRow(league) }
                            }
                        }.frame(maxHeight: 355)
                    }
                }.padding(0)
                aiTableRead
            }.frame(width: 260).padding(.vertical, 20).padding(.trailing, 20)
        }
    }
    @ViewBuilder private var leagueSection: some View {
        switch vm.leagueTab {
        case .standings:
            ForEach(vm.standings) { standing in
                Button { app.open(team: standing.team) } label: { row(standing) }.buttonStyle(.plain)
                if standing.id != vm.standings.last?.id { Divider().overlay(AppColors.border) }
            }
        case .fixtures:
            fixtureRows(vm.leagueFixtures, empty: "No upcoming fixtures are available for this competition.")
        case .results:
            fixtureRows(vm.leagueResults, empty: "No completed results are available for this competition.")
        case .scorers:
            if vm.scorers.isEmpty { tableMessage("Top-scorer data is not available for this competition.") }
            ForEach(Array(vm.scorers.enumerated()), id: \.element.id) { index, scorer in
                HStack(spacing: 10) {
                    Text("\(index + 1)").frame(width: 24)
                    RemoteBadge(url: scorer.photoURL, name: scorer.playerName, size: 22)
                    VStack(alignment: .leading) { Text(scorer.playerName).fontWeight(.semibold); if let team = scorer.teamName { Text(team).foregroundColor(AppColors.muted) } }
                    Spacer(); Text("\(scorer.goals)").fontWeight(.bold); Text("goals").foregroundColor(AppColors.muted)
                }.font(.system(size: 10)).padding(.horizontal, 12).padding(.vertical, 9)
                Divider().overlay(AppColors.border)
            }
        }
    }
    @ViewBuilder private func fixtureRows(_ fixtures: [Fixture], empty: String) -> some View {
        if fixtures.isEmpty { tableMessage(empty) }
        ForEach(fixtures.prefix(30)) { fixture in
            Button { app.open(fixture: fixture) } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fixture.league.name).font(.system(size: 8, design: .monospaced)).foregroundColor(AppColors.muted)
                        Text("\(fixture.homeTeam.name)  \(fixture.homeScore.map(String.init) ?? "–")  –  \(fixture.awayScore.map(String.init) ?? "–")  \(fixture.awayTeam.name)").font(.system(size: 10, weight: .medium))
                    }
                    Spacer(); Text(fixture.displayStatus).font(.system(size: 8, design: .monospaced)).foregroundColor(fixture.isLive ? AppColors.red : AppColors.muted)
                }.padding(.horizontal, 12).padding(.vertical, 9).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Divider().overlay(AppColors.border)
        }
    }
    private var tableHeader: some View {
        HStack {
            Text("#").frame(width: 26)
            Text("Club")
            Spacer()
            ForEach(["PL","W","D","L","GD","PTS"], id: \.self) { Text($0).frame(width: 38) }
            Text("Form").frame(width: 82)
        }.font(.system(size: 7, design: .monospaced)).tracking(1).foregroundColor(AppColors.muted)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color.white.opacity(0.012))
            .overlay(alignment: .bottom) { Rectangle().fill(AppColors.border).frame(height: 1) }
    }
    private func row(_ standing: Standing) -> some View {
        HStack(spacing: 8) {
            Rectangle().fill(positionColor(standing.position)).frame(width: 2, height: 22)
            Text("\(standing.position)").frame(width: 22)
            RemoteBadge(url: standing.team.badgeURL, name: standing.team.name, size: 18)
            Text(standing.team.name).fontWeight(.semibold).lineLimit(1)
            Spacer()
            ForEach(Array([standing.played, standing.won, standing.drawn, standing.lost, standing.goalDifference, standing.points].enumerated()), id: \.offset) { index, value in
                Text(index == 4 && value > 0 ? "+\(value)" : "\(value)").frame(width: 38)
            }
            formView(standing.form).frame(width: 82)
        }.font(.system(size: 10)).foregroundColor(AppColors.text)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .contentShape(Rectangle())
    }
    private func competitionRow(_ league: League) -> some View {
        Button {
            Task { await vm.loadStandings(league) }
        } label: {
            HStack(spacing: 9) {
                RemoteBadge(url: league.logoURL, name: league.name, size: 20)
                Text(league.name).lineLimit(1)
                Spacer()
                let liveCount = vm.liveCount(for: league)
                if liveCount > 0 {
                    Text("\(liveCount) live").font(.system(size: 7, design: .monospaced)).foregroundColor(AppColors.muted)
                }
            }
            .foregroundColor(vm.selectedLeague?.id == league.id ? AppColors.lime : AppColors.text)
            .font(.system(size: 10)).padding(.vertical, 8)
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private var aiTableRead: some View {
        Card(highlight: true) {
            VStack(alignment: .leading, spacing: 9) {
                Mono(text: "AI Table Read", color: AppColors.lime)
                switch vm.tableReadState {
                case .loading:
                    HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Reading the real table…") }
                        .font(.system(size: 10)).foregroundColor(AppColors.muted)
                case .loaded: Text(vm.tableRead ?? "Not available").font(.system(size: 10)).foregroundColor(AppColors.text).lineSpacing(3)
                case .offline: Text("You're offline.").font(.system(size: 10)).foregroundColor(AppColors.muted)
                case .failed(let message):
                    Text(message).font(.system(size: 10)).foregroundColor(AppColors.red)
                    PillButton(title: "Retry") { Task { await vm.generateTableRead() } }
                default: PillButton(title: "Generate grounded read") { Task { await vm.generateTableRead() } }
                }
            }
        }
    }
    private func tableMessage(_ text: String) -> some View { Text(text).font(.system(size: 11)).foregroundColor(AppColors.muted).frame(maxWidth: .infinity).padding(40) }
    private func positionColor(_ position: Int) -> Color { position <= 4 ? AppColors.lime : position <= 6 ? AppColors.blue : Color.clear }
    private func formView(_ form: String?) -> some View {
        HStack(spacing: 3) {
            ForEach(Array((form ?? "").prefix(5).enumerated()), id: \.offset) { _, result in
                Text(String(result)).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(result == "D" ? AppColors.text : .black)
                    .frame(width: 14, height: 14).background(Circle().fill(result == "W" ? AppColors.lime.opacity(0.75) : result == "L" ? AppColors.red.opacity(0.75) : AppColors.muted.opacity(0.5)))
            }
            if form?.isEmpty != false { Text("–").foregroundColor(AppColors.muted) }
        }
    }
}

struct TeamDetailView: View {
    @EnvironmentObject var vm: LeaguesTeamsViewModel
    @EnvironmentObject var app: AppViewModel
    @EnvironmentObject var account: AccountViewModel
    var body: some View {
        Group {
            switch vm.teamState {
            case .idle where app.selectedTeam == nil, .empty where app.selectedTeam == nil: ScreenStateView(title: "Select a team from Follow Setup or a league.", systemImage: "person.3")
            case .loading: ScreenStateView(title: "Loading team…", systemImage: "clock")
            case .offline: ScreenStateView(title: "You're offline.", systemImage: "wifi.slash") { Task { await vm.loadTeam(app.selectedTeam, force: true) } }
            case .failed(let message): ScreenStateView(title: "Unable to load team.", subtitle: message) { Task { await vm.loadTeam(app.selectedTeam, force: true) } }
            default: content
            }
        }.task(id: app.selectedTeam?.id) { await vm.loadTeam(app.selectedTeam) }
    }
    private var content: some View {
        ScrollView {
            if let team = vm.team {
                VStack(spacing: 16) {
                    HStack {
                        RemoteBadge(url: team.badgeURL, name: team.name, size: 52)
                        VStack(alignment: .leading) {
                            Text(team.name).font(.system(size: 26, weight: .bold))
                            Text([team.country, team.founded.map { "Est. \($0)" }].compactMap { $0 }.joined(separator: " · ")).foregroundColor(AppColors.muted)
                        }
                        Spacer()
                        PillButton(title: vm.isFollowing ? "Following" : "Follow", filled: !vm.isFollowing) { vm.toggleFollow() }.fixedSize()
                    }.padding(20).background(AppColors.card)
                    if let message = vm.followMessage { Text(message).font(.system(size: 10)).foregroundColor(AppColors.lime).frame(maxWidth: .infinity, alignment: .trailing) }
                    HStack(alignment: .top, spacing: 16) {
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Squad").fontWeight(.semibold)
                                if vm.squad.isEmpty { Text("Squad data is not available.").foregroundColor(AppColors.muted) }
                                ForEach(vm.squad) { player in
                                    Divider().overlay(AppColors.border)
                                    HStack { Text(player.number ?? "–").frame(width: 30); Text(player.name); Spacer(); Text(player.position ?? "–").foregroundColor(AppColors.muted); Text(player.goals.map { "\($0) G" } ?? "–").frame(width: 45); Text(player.assists.map { "\($0) A" } ?? "–").frame(width: 45) }.font(.system(size: 10))
                                }
                            }
                        }
                        VStack(spacing: 14) {
                            fixtureCard(title: "Next fixtures", fixtures: vm.fixtures, empty: "No upcoming fixtures.")
                            fixtureCard(title: "Recent results", fixtures: vm.teamResults, empty: "No recent results are available.")
                            Card {
                                VStack(alignment: .leading, spacing: 9) {
                                    Mono(text: "Season shape")
                                    if vm.teamMetrics.isEmpty { Text("The API did not provide team statistics for this season.").font(.system(size: 9)).foregroundColor(AppColors.muted) }
                                    ForEach(vm.teamMetrics.prefix(8)) { metric in HStack { Text(metric.name); Spacer(); Text(metric.value).fontWeight(.semibold) }.font(.system(size: 9)) }
                                }
                            }
                        }.frame(width: 280)
                    }.padding(20)
                }
            }
        }
    }
    private func fixtureCard(title: String, fixtures: [Fixture], empty: String) -> some View {
        Card { VStack(alignment: .leading, spacing: 9) {
            Mono(text: title)
            if fixtures.isEmpty { Text(empty).font(.system(size: 9)).foregroundColor(AppColors.muted) }
            ForEach(fixtures.prefix(6)) { fixture in
                Button { app.open(fixture: fixture) } label: { VStack(alignment: .leading, spacing: 2) { Text("\(fixture.homeTeam.name) vs \(fixture.awayTeam.name)").font(.system(size: 10)); Text(fixture.kickoff.map(account.kickoffString) ?? fixture.displayStatus).font(.system(size: 8, design: .monospaced)).foregroundColor(AppColors.muted) } }.buttonStyle(.plain)
            }
        } }
    }
}
