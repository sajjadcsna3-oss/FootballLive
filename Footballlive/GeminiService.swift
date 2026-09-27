import Foundation

struct MatchContextBuilder {
    static func build(fixture: Fixture?, statistics: [MatchStatistic], events: [MatchEvent]) -> String {
        guard let fixture else { return "No match is currently selected. Do not invent match facts or numbers." }
        let stats = statistics.map { statistic in
            let home = statistic.home.map { String($0) } ?? "unavailable"
            let away = statistic.away.map { String($0) } ?? "unavailable"
            return "\(statistic.name): home=\(home), away=\(away)"
        }.joined(separator: "\n")
        let recent = events.suffix(12).map { "\($0.minute.map(String.init) ?? "?")' \($0.type): \($0.playerName ?? $0.detail ?? "")" }.joined(separator: "\n")
        return """
        Match: \(fixture.homeTeam.name) vs \(fixture.awayTeam.name)
        Status: \(fixture.displayStatus)
        Score: \(fixture.homeScore.map(String.init) ?? "unavailable")-\(fixture.awayScore.map(String.init) ?? "unavailable")
        Statistics (only these are known):
        \(stats.isEmpty ? "No statistics available." : stats)
        Recent events:
        \(recent.isEmpty ? "No events available." : recent)
        """
    }
}

/// Keeps request encoding and response decoding off the SwiftUI main actor.
actor GeminiService {
    static let shared = GeminiService()
    private let network = NetworkService()

    private struct RequestBody: Encodable {
        let systemInstruction: Content
        let contents: [Content]
        let generationConfig: GenerationConfig
    }
    private struct Content: Codable { let role: String?; let parts: [Part] }
    private struct Part: Codable { let text: String }
    private struct GenerationConfig: Encodable { let temperature: Double; let maxOutputTokens: Int }
    private struct ResponseBody: Decodable {
        let candidates: [Candidate]?
        let promptFeedback: PromptFeedback?
        struct Candidate: Decodable { let content: Content }
        struct PromptFeedback: Decodable { let blockReason: String? }
    }
    private struct BackendRequest: Encodable { let question: String; let context: String }
    private struct BackendResponse: Decodable { let answer: String }

    func answer(question: String, context: String) async throws -> String {
        if let backend = APIConfiguration.backendBaseURL {
            let url = backend.appending(path: "v1/ai/commentary")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(BackendRequest(question: question, context: context))
            let data = try await network.data(for: request)
            return try JSONDecoder().decode(BackendResponse.self, from: data).answer
        }
        guard let key = APIConfiguration.geminiAPIKey else { throw NetworkError.missingConfiguration("GEMINI_API_KEY") }
        let modelPath = "models/\(APIConfiguration.geminiModel):generateContent"
        var components = URLComponents(url: APIConfiguration.geminiBaseURL, resolvingAgainstBaseURL: false)!
        components.path = APIConfiguration.geminiBaseURL.path + "/" + modelPath
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let rules = "You are Tempo, a concise football analyst. Use only facts and numbers explicitly supplied in the context. Never estimate or invent scores, goals, cards, xG, possession, shots, PPDA, probabilities, player statistics, or other numeric football facts. If evidence is missing, clearly say it is unavailable. Distinguish observation from inference."
        request.httpBody = try JSONEncoder().encode(RequestBody(
            systemInstruction: Content(role: nil, parts: [Part(text: rules)]),
            contents: [Content(role: "user", parts: [Part(text: "\(context)\n\nQuestion: \(question)")])],
            generationConfig: GenerationConfig(temperature: 0.2, maxOutputTokens: 700)
        ))
        let data = try await network.data(for: request)
        let response = try JSONDecoder().decode(ResponseBody.self, from: data)
        if let answer = response.candidates?.first?.content.parts.compactMap(\.text).joined(separator: "\n"), !answer.isEmpty { return answer }
        if let reason = response.promptFeedback?.blockReason { throw GeminiError.blocked(reason) }
        throw NetworkError.invalidResponse
    }

    enum GeminiError: LocalizedError {
        case blocked(String)
        var errorDescription: String? { switch self { case .blocked(let reason): return "Gemini blocked this request: \(reason)." } }
    }
}
