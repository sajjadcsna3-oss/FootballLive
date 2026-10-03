//
//  Followsetupview.swift
//  Footballlive
//
//  Created by Mac Mini on 24/09/2026.
//

import SwiftUI

// MARK: - Follow Setup (3 steps)
struct FollowSetupView: View {
    @EnvironmentObject var vm: FollowSetupViewModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) { ForEach(1...3, id: \.self) { i in Rectangle().fill(i <= vm.step ? AppColors.lime : Color.white.opacity(0.1)).frame(height: 2) } }
                switch vm.step {
                case 1: TeamSelectionView()
                case 2: ExcitementSetupView()
                default: FeedReadyView()
                }
            }.frame(maxWidth: 580).padding(.top, 30).frame(maxWidth: .infinity)
        }.task { await vm.load() }
    }
}

struct SetupHeading: View {
    let title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title)).font(.system(size: 26, weight: .bold)).foregroundColor(AppColors.text)
            Text(LocalizedStringKey(subtitle)).font(.system(size: 12)).foregroundColor(AppColors.muted)
        }
    }
}

struct TeamSelectionView: View {
    @EnvironmentObject var vm: FollowSetupViewModel
    @EnvironmentObject var app: AppViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SetupHeading(title: "Who should we watch for you?", subtitle: "Pick your teams. Tempo learns which moments actually pull you in and quiets everything else.")
            Mono(text: "Sports", size: 8)
            Text("Football").font(.system(size: 11, weight: .semibold)).foregroundColor(AppColors.text).padding(.horizontal, 14).padding(.vertical, 8)
                .background(AppColors.lime.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.lime))
            Mono(text: "Teams · \(vm.selectedTeams.count) selected", size: 8)
            if vm.state == .loading { ProgressView().tint(AppColors.lime) }
            if case .failed(let message) = vm.state { Text(message).font(.system(size: 10)).foregroundColor(AppColors.red); PillButton(title: "Retry") { Task { await vm.load(force: true) } }.fixedSize() }
            if vm.state == .offline { Text("You're offline. Check your connection and retry.").font(.system(size: 10)).foregroundColor(AppColors.muted); PillButton(title: "Retry") { Task { await vm.load(force: true) } }.fixedSize() }
            if vm.state == .empty { Text("No teams are currently available from the API.").font(.system(size: 10)).foregroundColor(AppColors.muted); PillButton(title: "Retry") { Task { await vm.load(force: true) } }.fixedSize() }
            if let message = vm.limitMessage { Text(message).font(.system(size: 10)).foregroundColor(AppColors.lime) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(vm.teams) { t in
                    let on = vm.selectedTeams.contains(t.name)
                    Button { if !vm.toggle(t) { app.openPremium() } } label: {
                        HStack(spacing: 6) {
                            RemoteBadge(url: t.badgeURL, name: t.code, size: 20)
                            Text(t.name).font(.system(size: 11, weight: on ? .semibold : .regular)).foregroundColor(on ? AppColors.text : AppColors.muted)
                            Spacer(minLength: 0)
                        }.padding(10).background(on ? AppColors.lime.opacity(0.08) : AppColors.card)
                            .clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(on ? AppColors.lime : AppColors.border))
                    }.buttonStyle(.plain)
                }
            }
            HStack(spacing: 14) {
                PillButton(title: "Continue") { vm.next() }.fixedSize()
                Button { vm.skip() } label: { Text("Skip for now").font(.system(size: 10)).foregroundColor(AppColors.muted) }.buttonStyle(.plain)
            }
        }
    }
}

struct ExcitementSetupView: View {
    @EnvironmentObject var vm: FollowSetupViewModel
    @EnvironmentObject var account: AccountViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SetupHeading(title: "How loud should Tempo be?", subtitle: "Choose when the app should alert you while it is receiving match data. You can change this any time.")
            Card(highlight: true) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) { ThresholdSlider(value: $account.threshold); Text(account.thresholdText).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundColor(AppColors.lime) }
                    HStack { Mono(text: "Everything", size: 7); Spacer(); Mono(text: "Only the good stuff", size: 7); Spacer(); Mono(text: "Finals only", size: 7) }
                    Text("Alerts are delivered only when real match data received by the app crosses this threshold.").font(.system(size: 10)).foregroundColor(AppColors.muted)
                }
            }
            AlertToggleList(kinds: [.goals, .surge, .startingSoon, .recap])
            HStack(spacing: 14) {
                PillButton(title: "Continue") { vm.next() }.fixedSize()
                Button { vm.back() } label: { Text("Back").font(.system(size: 10)).foregroundColor(AppColors.muted) }.buttonStyle(.plain)
            }
        }
    }
}

struct FeedReadyView: View {
    @EnvironmentObject var vm: FollowSetupViewModel
    @EnvironmentObject var account: AccountViewModel
    @EnvironmentObject var app: AppViewModel
    var body: some View {
        VStack(spacing: 16) {
            Circle().fill(AppColors.lime).frame(width: 50, height: 50).overlay(Circle().fill(Color.black).frame(width: 14, height: 14))
            Text("Your feed is ready.").font(.system(size: 26, weight: .bold)).foregroundColor(AppColors.text)
            Text("Football Live will use available match data for \(vm.selectedTeams.count) followed teams. Live goal and momentum alerts require the app to be running and receiving updates.").font(.system(size: 11)).foregroundColor(AppColors.muted)
            HStack(spacing: 12) {
                summary("Teams", "\(vm.selectedTeams.count)", "Saved as followed teams")
                summary("Sports", "\(vm.sportsCount)", "Coverage depends on the provider")
                summary("Threshold", account.thresholdText, "Applied when match data is fetched")
            }
            HStack(spacing: 10) {
                PillButton(title: "Open Tempo") { Task { await vm.complete(); app.open(.live) } }.frame(width: 140)
                if !EntitlementService.shared.isPro { PillButton(title: "View Tempo Pro", filled: false) { app.open(.pro) }.frame(width: 170) }
            }
        }.frame(maxWidth: .infinity)
    }
    func summary(_ l: String, _ v: String, _ s: String) -> some View {
        Card { VStack(alignment: .leading, spacing: 5) { Mono(text: l, size: 7); Text(v).font(.system(size: 20, weight: .bold)).foregroundColor(AppColors.text); Text(s).font(.system(size: 9)).foregroundColor(AppColors.muted) } }
    }
}
