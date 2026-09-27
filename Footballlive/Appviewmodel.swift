import SwiftUI
import Combine

@MainActor final class AppViewModel: ObservableObject {
    @Published var selection: NavItem = UserDefaults.standard.bool(forKey: "setupCompleted") ? .live : .follow
    @Published var liveCount = 0
    @Published var selectedFixture: Fixture?
    @Published var selectedLeague: League?
    @Published var selectedTeam: Team?
    func open(_ item: NavItem) { selection = item }
    func open(fixture: Fixture) { selectedFixture = fixture; selection = .match }
    func open(team: Team) { selectedTeam = team; selection = .teams }
}
