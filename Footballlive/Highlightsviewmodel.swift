import SwiftUI
import Combine

@MainActor final class HighlightsViewModel: ObservableObject {
    @Published private(set) var highlights: [Highlight] = []
    @Published var selected: Highlight?
    @Published private(set) var state: LoadState = .idle
    @Published var autoplay: Bool { didSet { UserDefaults.standard.set(autoplay, forKey: "autoplayHighlights") } }
    @Published var selectedCategory = "Latest"
    @Published private(set) var analysis: String?
    @Published private(set) var analysisState: LoadState = .idle
    @Published private(set) var matchError: String?
    @Published private(set) var savedIDs: Set<String>
    private let service: GoalAPIService
    private let gemini: GeminiService
    init(service: GoalAPIService? = nil, gemini: GeminiService? = nil) {
        self.service = service ?? .shared
        self.gemini = gemini ?? .shared
        self.autoplay = UserDefaults.standard.object(forKey: "autoplayHighlights") as? Bool ?? true
        self.savedIDs = Set(UserDefaults.standard.stringArray(forKey: "savedHighlightIDs") ?? [])
    }
    func isSaved(_ highlight: Highlight) -> Bool { savedIDs.contains(highlight.id) }
    func toggleSaved(_ highlight: Highlight) {
        if savedIDs.contains(highlight.id) { savedIDs.remove(highlight.id) } else { savedIDs.insert(highlight.id) }
        UserDefaults.standard.set(Array(savedIDs), forKey: "savedHighlightIDs")
    }
    func followTeamsForSelected() async {
        guard let fixture = await fixtureForSelected() else { return }
        var names = Set(UserDefaults.standard.stringArray(forKey: "followedTeamNames") ?? [])
        for team in [fixture.homeTeam, fixture.awayTeam] where !names.contains(team.name) {
            guard EntitlementService.shared.canFollow(teamCount: names.count) else {
                matchError = L10n.text("The Free plan supports up to 5 followed teams. Tempo Pro removes this limit.")
                break
            }
            names.insert(team.name)
        }
        UserDefaults.standard.set(Array(names), forKey: "followedTeamNames")
    }

    var categories: [String] {
        let values = Set(highlights.compactMap { value in
            let category = value.category?.trimmingCharacters(in: .whitespacesAndNewlines)
            return category?.isEmpty == false ? category : nil
        })
        return ["Latest"] + values.sorted()
    }
    var filteredHighlights: [Highlight] {
        selectedCategory == "Latest" ? highlights : highlights.filter { $0.category == selectedCategory }
    }
    var upNext: [Highlight] { highlights.filter { $0.id != selected?.id }.prefix(6).map { $0 } }

    func load(force: Bool = false) async {
        if !force, state == .loaded { return }
        state = .loading
        do {
            highlights = try await service.highlights().filter { $0.playableURL != nil }
            if !categories.contains(selectedCategory) { selectedCategory = "Latest" }
            state = highlights.isEmpty ? .empty : .loaded
        } catch NetworkError.offline { state = .offline }
        catch { state = .failed(error.localizedDescription) }
    }
    func select(_ highlight: Highlight) {
        selected = highlight
        analysis = nil
        analysisState = .idle
        matchError = nil
    }
    func closePlayer() {
        selected = nil
        analysis = nil
        analysisState = .idle
        matchError = nil
    }
    func fixtureForSelected() async -> Fixture? {
        guard let id = selected?.fixtureId else {
            matchError = "This highlight is not linked to a GOAL fixture."
            return nil
        }
        do { return try await service.fixture(id: id) }
        catch { matchError = error.localizedDescription; return nil }
    }
    func loadAnalysis() async {
        guard analysisState == .idle, let selected, let fixtureID = selected.fixtureId else { return }
        if !EntitlementService.shared.canUseAI { analysisState = .failed(L10n.text("Free AI limit reached. Upgrade to Tempo Pro for unlimited reads.")); return }
        analysisState = .loading
        do {
            async let fixture = service.fixture(id: fixtureID)
            async let events = service.events(id: fixtureID)
            async let statistics = service.statistics(id: fixtureID)
            let loadedFixture = try await fixture
            let context = MatchContextBuilder.build(
                fixture: loadedFixture,
                statistics: (try? await statistics) ?? [],
                events: (try? await events) ?? []
            ) + "\nHighlight title: \(selected.title)"
            analysis = try await gemini.answer(
                question: "Explain this highlight briefly using only the supplied match facts. Do not invent metrics or events.",
                context: context
            )
            UsageMetricsService.shared.recordAIRead()
            _ = EntitlementService.shared.consumeAIRequest()
            analysisState = .loaded
        } catch NetworkError.offline { analysisState = .offline }
        catch { analysisState = .failed(error.localizedDescription) }
    }
}
