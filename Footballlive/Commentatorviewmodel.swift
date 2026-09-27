import SwiftUI
import Combine

@MainActor final class CommentatorViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var input = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    let chips = ["What changed tactically?", "Explain the recent momentum", "Who has been more dangerous?", "Summarise this match"]
    private let gemini: GeminiService
    init(gemini: GeminiService? = nil) { self.gemini = gemini ?? .shared }
    func send(_ suggested: String? = nil, fixture: Fixture?, statistics: [MatchStatistic], events: [MatchEvent]) async {
        let question = (suggested ?? input).trimmingCharacters(in: .whitespacesAndNewlines); guard !question.isEmpty, !isLoading else { return }
        if !EntitlementService.shared.canUseAI { errorMessage = L10n.text("Free AI limit reached. Upgrade to Tempo Pro for unlimited reads."); return }
        messages.append(ChatMessage(isUser: true, text: [question])); input = ""; isLoading = true; errorMessage = nil
        do { let answer = try await gemini.answer(question: question, context: MatchContextBuilder.build(fixture: fixture, statistics: statistics, events: events)); messages.append(ChatMessage(isUser: false, text: [answer])); _ = EntitlementService.shared.consumeAIRequest(); UsageMetricsService.shared.recordAIRead() } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
    func clear() { messages = []; errorMessage = nil }
}
