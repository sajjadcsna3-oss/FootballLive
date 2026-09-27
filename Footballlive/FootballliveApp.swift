//
//  FootballliveApp.swift
//  Footballlive
//
//  Created by Mac Mini on 24/09/2026.
//

import SwiftUI
import SwiftData
import AppKit

// MARK: - App entry. All ViewModels are created once here and shared through the environment.
@main
struct FootBallLiveApp: App {
    @StateObject private var app = AppViewModel()
    @StateObject private var account = AccountViewModel()
    @StateObject private var entitlements = EntitlementService.shared
    @StateObject private var live = LiveScoresViewModel()
    @StateObject private var match = MatchCenterViewModel()
    @StateObject private var highlights = HighlightsViewModel()
    @StateObject private var leagues = LeaguesTeamsViewModel()
    @StateObject private var commentator = CommentatorViewModel()
    @StateObject private var follow = FollowSetupViewModel()

    init() { APIConfiguration.bootstrap() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(app).environmentObject(account).environmentObject(live)
                .environmentObject(match).environmentObject(highlights).environmentObject(leagues)
                .environmentObject(commentator).environmentObject(follow)
                .environmentObject(entitlements)
                .frame(minWidth: 1000, minHeight: 640)
                .preferredColorScheme(account.darkAppearance ? .dark : .light)
                .environment(\.locale, account.locale)
                .environment(\.layoutDirection, account.layoutDirection)
                .modelContainer(for: [FollowedTeam.self, UserPreferences.self])
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .windowResizability(.contentMinSize)

        MenuBarExtra(isInserted: $account.menuBarScore) {
            MenuBarScoreView()
                .environmentObject(app).environmentObject(account).environmentObject(live).environmentObject(entitlements)
        } label: {
            Label(app.liveCount > 0 ? "\(app.liveCount) Live" : "Tempo", systemImage: "soccerball")
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarScoreView: View {
    @EnvironmentObject var app: AppViewModel
    @EnvironmentObject var live: LiveScoresViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Football Live").font(.headline)
            if live.state == .loading || live.state == .idle { ProgressView() }
            else if live.leagues.isEmpty { Text("No live matches right now.").foregroundStyle(.secondary) }
            else {
                ForEach(live.leagues.flatMap(\.matches).prefix(5)) { fixture in
                    Button { app.open(fixture: fixture); NSApp.activate(ignoringOtherApps: true) } label: {
                        HStack { Text("\(fixture.homeTeam.name) \(fixture.homeScore ?? 0)–\(fixture.awayScore ?? 0) \(fixture.awayTeam.name)"); Spacer(); Text(fixture.displayStatus) }
                    }.buttonStyle(.plain)
                }
            }
        }.padding(12).frame(width: 330)
        .task {
            try? await Task.sleep(for: .milliseconds(1))
            guard !Task.isCancelled else { return }
            await live.load(force: true)
            app.liveCount = live.leagues.flatMap(\.matches).count
        }
    }
}
