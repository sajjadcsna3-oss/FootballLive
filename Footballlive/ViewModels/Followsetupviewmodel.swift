import SwiftUI
import Combine

@MainActor final class FollowSetupViewModel: ObservableObject {
    @Published var step = 1
    @Published var selectedTeams: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "followedTeamNames") ?? [])
    @Published private(set) var selectedTeamIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "followedTeamIDs") ?? [])
    @Published private(set) var teams: [TeamOption] = []
    @Published private(set) var state: LoadState = .idle
    @Published var limitMessage: String?
    let sportsCount = 1
    private let service: GoalAPIService
    init(service: GoalAPIService? = nil) { self.service = service ?? .shared }
    func load(force: Bool = false) async {
        if !force, !teams.isEmpty { return }
        state = .loading
        do {
            teams = try await service.teams().map { TeamOption(id: $0.id, code: String($0.name.prefix(3)).uppercased(), name: $0.name, colorHex: "263141", badgeURL: $0.badgeURL) }
            state = teams.isEmpty ? .empty : .loaded
        } catch NetworkError.offline { state = .offline }
        catch { state = .failed(error.localizedDescription) }
    }
    @discardableResult
    func toggle(_ team: TeamOption) -> Bool {
        if selectedTeams.contains(team.name) { selectedTeams.remove(team.name); selectedTeamIDs.remove(team.id) }
        else {
            guard EntitlementService.shared.canFollow(teamCount: selectedTeams.count) else {
                limitMessage = L10n.text("The Free plan supports up to 5 followed teams. Tempo Pro removes this limit.")
                return false
            }
            selectedTeams.insert(team.name); selectedTeamIDs.insert(team.id)
        }
        limitMessage = nil
        UserDefaults.standard.set(Array(selectedTeams), forKey: "followedTeamNames")
        UserDefaults.standard.set(Array(selectedTeamIDs), forKey: "followedTeamIDs")
        return true
    }
    func next() { step = min(3, step + 1) }
    func back() { step = max(1, step - 1) }
    func skip() { step = 3 }
    func complete() async {
        UserDefaults.standard.set(true, forKey: "setupCompleted")
        _ = try? await NotificationService.shared.requestAuthorization()
        await NotificationService.shared.reconcileSavedPreferences()
    }
}
