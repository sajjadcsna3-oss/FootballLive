import SwiftUI
import AVKit
import WebKit

struct HighlightsView: View {
    @EnvironmentObject var vm: HighlightsViewModel
    var body: some View {
        Group {
            switch vm.state {
            case .idle, .loading: ScreenStateView(title: "Loading highlights…", systemImage: "play.rectangle")
            case .empty: ScreenStateView(title: "No highlights are currently available.", subtitle: "GOAL API has not returned any playable videos.", systemImage: "play.slash") { Task { await vm.load(force: true) } }
            case .offline: ScreenStateView(title: "You're offline.", systemImage: "wifi.slash") { Task { await vm.load(force: true) } }
            case .failed(let message): ScreenStateView(title: "Unable to load highlights.", subtitle: message) { Task { await vm.load(force: true) } }
            case .loaded: content
            }
        }
        .task { await vm.load() }
        .onReceive(NotificationCenter.default.publisher(for: .autoplayPreferenceChanged)) { note in
            if let enabled = note.object as? Bool { vm.autoplay = enabled }
        }
    }
    private var content: some View {
        ScrollView {
            if let selected = vm.selected {
                HighlightPlayerView(highlight: selected)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HighlightFilters()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 16)], spacing: 16) {
                        ForEach(vm.filteredHighlights) { highlight in
                            Button { vm.select(highlight) } label: { HighlightCard(highlight: highlight) }
                                .buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
        }.refreshable { await vm.load(force: true) }
    }
}

private struct HighlightFilters: View {
    @EnvironmentObject var vm: HighlightsViewModel
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.categories, id: \.self) { category in
                    Button(category) { vm.selectedCategory = category }
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(vm.selectedCategory == category ? .black : AppColors.text)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(vm.selectedCategory == category ? AppColors.lime : AppColors.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.border))
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

struct HighlightThumbnail: View {
    let highlight: Highlight
    var compact = false
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: highlight.thumbnailURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else {
                    ZStack {
                        LinearGradient(colors: [Color(hex: "102735"), Color(hex: "07131B")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "play.fill").font(.system(size: compact ? 13 : 24, weight: .bold)).foregroundColor(AppColors.lime)
                    }
                }
            }.clipped()
            if let duration = highlight.duration {
                Text(duration).font(.system(size: 8, weight: .semibold, design: .monospaced)).padding(.horizontal, 4).padding(.vertical, 2).background(Color.black.opacity(0.8)).padding(5)
            }
        }
    }
}

struct HighlightCard: View {
    let highlight: Highlight
    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HighlightThumbnail(highlight: highlight).frame(height: 150)
                Text(highlight.title).font(.system(size: 12, weight: .semibold)).foregroundColor(AppColors.text).lineLimit(2).padding(.horizontal, 12)
                Mono(text: highlight.competition ?? highlight.category ?? highlight.sourceName ?? "Highlight", size: 7).padding([.horizontal, .bottom], 12)
            }
        }
    }
}

struct HighlightPlayerView: View {
    let highlight: Highlight
    @EnvironmentObject var vm: HighlightsViewModel
    @EnvironmentObject var app: AppViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    HighlightMediaView(highlight: highlight, autoplay: vm.autoplay).frame(minHeight: 380)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(highlight.title).font(.system(size: 18, weight: .bold)).foregroundColor(AppColors.text)
                        Mono(text: [highlight.competition, highlight.duration, highlight.sourceName].compactMap { $0 }.joined(separator: "  ·  "), size: 7)
                        HStack {
                            if highlight.fixtureId != nil {
                                PillButton(title: "Open match center") {
                                    Task { if let fixture = await vm.fixtureForSelected() { app.open(fixture: fixture) } }
                                }.fixedSize()
                            }
                            PillButton(title: vm.isSaved(highlight) ? "Saved" : "Save", filled: false) { vm.toggleSaved(highlight) }.fixedSize()
                            if let url = highlight.playableURL { ShareLink(item: url, subject: Text(highlight.title)) { Text("Share").font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.text).padding(.horizontal, 14).padding(.vertical, 8).overlay(Capsule().stroke(AppColors.border)) }.buttonStyle(.plain) }
                            if highlight.fixtureId != nil { PillButton(title: "Follow teams", filled: false) {
                                Task { if !(await vm.followTeamsForSelected()) { app.openPremium() } }
                            }.fixedSize() }
                            PillButton(title: "Back to highlights", filled: false) { vm.closePlayer() }.fixedSize()
                        }
                        if let matchError = vm.matchError { Text(matchError).font(.system(size: 10)).foregroundColor(AppColors.red) }
                    }.padding(16)
                }
                .background(AppColors.card).clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border))
                HighlightUpNext().frame(width: 270)
            }
            HighlightAnalysisCard().task(id: highlight.id) { await vm.loadAnalysis() }
        }.padding(20)
    }
}

private struct HighlightUpNext: View {
    @EnvironmentObject var vm: HighlightsViewModel
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Mono(text: "Up next"); Spacer(); Toggle("", isOn: $vm.autoplay).labelsHidden().toggleStyle(LimeToggle()) }
                if vm.upNext.isEmpty { Text("No more highlights available.").font(.system(size: 10)).foregroundColor(AppColors.muted) }
                ForEach(vm.upNext) { item in
                    Button { vm.select(item) } label: {
                        HStack(spacing: 9) {
                            HighlightThumbnail(highlight: item, compact: true).frame(width: 82, height: 48).clipShape(RoundedRectangle(cornerRadius: 5))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.system(size: 10, weight: .semibold)).foregroundColor(AppColors.text).lineLimit(2)
                                Mono(text: item.competition ?? item.category ?? "Highlight", size: 6)
                            }
                        }
                    }.buttonStyle(.plain)
                    if item.id != vm.upNext.last?.id { Divider().overlay(AppColors.border) }
                }
            }
        }
    }
}

private struct HighlightAnalysisCard: View {
    @EnvironmentObject var vm: HighlightsViewModel
    @EnvironmentObject var aiConsent: AIConsentService
    var body: some View {
        if !aiConsent.hasConsent {
            AIConsentNotice()
        } else {
        Card(highlight: true) {
            VStack(alignment: .leading, spacing: 10) {
                Mono(text: "AI clip breakdown", color: AppColors.lime)
                switch vm.analysisState {
                case .idle: Text("Match context is not available for this video.").foregroundColor(AppColors.muted)
                case .loading: ProgressView().controlSize(.small)
                case .loaded: Text(vm.analysis ?? "Not available")
                case .empty: Text("Not available").foregroundColor(AppColors.muted)
                case .offline: Text("You're offline.").foregroundColor(AppColors.muted)
                case .failed(let message): Text(message).foregroundColor(AppColors.red)
                }
            }.font(.system(size: 11))
        }
        }
    }
}

private struct HighlightMediaView: View {
    let highlight: Highlight
    let autoplay: Bool
    var body: some View {
        Group {
            if let url = highlight.videoURL { DirectVideoView(url: url, autoplay: autoplay) }
            else if let url = highlight.embedURL { WebVideoView(url: url) }
            else { ScreenStateView(title: "This video cannot be played.", subtitle: "GOAL API did not return a playable URL.", systemImage: "play.slash") }
        }.background(Color.black)
    }
}

private struct DirectVideoView: View {
    let url: URL
    let autoplay: Bool
    @State private var player = AVPlayer()
    @State private var failed = false
    var body: some View {
        Group {
            if failed { ScreenStateView(title: "Unable to play this video.", subtitle: "The video provider rejected the stream or it is no longer available.", systemImage: "play.slash") }
            else { VideoPlayer(player: player) }
        }
        .onAppear {
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            if autoplay { player.play() }
        }
        .onChange(of: autoplay) { _, enabled in enabled ? player.play() : player.pause() }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime)) { _ in failed = true }
        .onDisappear { player.pause() }
    }
}

struct WebVideoView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        return WKWebView(frame: .zero, configuration: configuration)
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        if view.url != url { view.load(URLRequest(url: url)) }
    }
}
