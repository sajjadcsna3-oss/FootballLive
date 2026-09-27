//
//  Rootviews.swift
//  Footballlive
//
//  Created by Mac Mini on 24/09/2026.
//

import SwiftUI

// MARK: - Root layout
struct ContentView: View {
    @EnvironmentObject var app: AppViewModel
    @EnvironmentObject var follow: FollowSetupViewModel

    var subtitle: String {
        if app.selection == .follow { return "Step \(follow.step) of 3" }
        if app.selection == .match, let fixture = app.selectedFixture { return "\(fixture.league.name) · \(fixture.displayStatus)" }
        if app.selection == .teams, let team = app.selectedTeam { return [team.country, team.founded.map { "Est. \($0)" }].compactMap { $0 }.joined(separator: " · ") }
        if app.selection == .leagues, let league = app.selectedLeague { return [league.countryName, league.season.map { "Season \($0)" }].compactMap { $0 }.joined(separator: " · ") }
        return app.selection.header.subtitle
    }
    var title: String {
        if app.selection == .match, let fixture = app.selectedFixture { return "\(fixture.homeTeam.name) vs \(fixture.awayTeam.name)" }
        if app.selection == .teams, let team = app.selectedTeam { return team.name }
        if app.selection == .leagues, let league = app.selectedLeague { return league.name }
        return app.selection.header.title
    }
    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            VStack(spacing: 0) {
                TopBarView(title: title, subtitle: subtitle)
                Divider().overlay(AppColors.border)
                screen.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(AppColors.bg)
    }

    @ViewBuilder var screen: some View {
        switch app.selection {
        case .live: LiveScoresView()
        case .match: MatchCenterView()
        case .highlights: HighlightsView()
        case .leagues: LeaguesView()
        case .teams: TeamDetailView()
        case .commentator: CommentatorView()
        case .follow: FollowSetupView()
        case .alerts: AlertsProfileView()
        case .settings: SettingsView()
        case .pro: TempoProView()
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @EnvironmentObject var app: AppViewModel
    @EnvironmentObject var entitlements: EntitlementService
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Circle().fill(AppColors.lime).frame(width: 24, height: 24)
                    .overlay(Image(systemName: "soccerball").font(.system(size: 13)).foregroundColor(.black))
                VStack(alignment: .leading, spacing: 1) {
                    Text("FootBall Live").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(AppColors.text)
                    Mono(text: "Scores · AI Analysis", size: 6)
                }
            }.padding(.top, 34).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(NavItem.sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 2) {
                            Mono(text: section.0, size: 8).padding(.leading, 8).padding(.bottom, 4)
                            ForEach(section.1, id: \.self) { item in row(item) }
                        }
                    }
                }.padding(.top, 8)
            }
            Spacer(minLength: 8)
            if !entitlements.isPro { proCard }
        }
        .padding(.horizontal, 12).padding(.bottom, 12)
        .frame(width: 190).background(AppColors.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(AppColors.border).frame(width: 1) }
    }

    func row(_ item: NavItem) -> some View {
        let selected = app.selection == item
        return Button { app.open(item) } label: {
            HStack(spacing: 8) {
                Circle().fill(selected ? AppColors.lime : Color.white.opacity(0.2)).frame(width: 5, height: 5)
                Text(LocalizedStringKey(item.rawValue)).font(.system(size: 12)).foregroundColor(selected ? AppColors.text : AppColors.muted)
                Spacer()
                if item == .live { Text("\(app.liveCount)").font(.system(size: 9, design: .monospaced)).foregroundColor(AppColors.red) }
                if item == .match { Text("LIVE").font(.system(size: 8, design: .monospaced)).foregroundColor(AppColors.red) }
                if item == .commentator { Text("AI").font(.system(size: 8, design: .monospaced)).foregroundColor(AppColors.lime) }
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .background(selected ? Color.white.opacity(0.06) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
    }

    var proCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Mono(text: "Tempo Pro", size: 8, color: AppColors.lime)
            Text("Unlimited AI reads, followed teams, and momentum alerts.").font(.system(size: 11)).foregroundColor(AppColors.text.opacity(0.85))
            PillButton(title: "View Tempo Pro") { app.open(.pro) }
        }
        .padding(12).background(AppColors.lime.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.lime.opacity(0.35)))
    }
}

// MARK: - Top bar
struct TopBarView: View {
    @EnvironmentObject var app: AppViewModel
    @EnvironmentObject var account: AccountViewModel
    let title: String
    let subtitle: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(title)).font(.system(size: 15, weight: .semibold)).foregroundColor(AppColors.text)
                Mono(text: subtitle, size: 8)
            }
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(AppColors.red).frame(width: 5, height: 5)
                Mono(text: L10n.text("%lld live now", app.liveCount), size: 9, color: AppColors.text)
            }.padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(AppColors.card)).overlay(Capsule().stroke(AppColors.border))
            HStack(spacing: 8) {
                Text(account.name.components(separatedBy: " ").first ?? "").font(.system(size: 10)).foregroundColor(AppColors.text)
                Text(account.initials).font(.system(size: 9, weight: .bold)).foregroundColor(AppColors.lime)
                    .frame(width: 20, height: 20).background(Circle().fill(Color.white.opacity(0.08)))
            }.padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(AppColors.card)).overlay(Capsule().stroke(AppColors.border))
        }
        .padding(.horizontal, 20).padding(.top, 26).padding(.bottom, 12)
    }
}
