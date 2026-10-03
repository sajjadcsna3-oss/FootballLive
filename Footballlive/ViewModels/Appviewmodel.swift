import SwiftUI
import Combine

@MainActor final class AppViewModel: ObservableObject {
    @Published var selection: NavItem = UserDefaults.standard.bool(forKey: "setupCompleted") ? .live : .follow
    @Published var liveCount = 0
    @Published var selectedFixture: Fixture?
    @Published var selectedLeague: League?
    @Published var selectedTeam: Team?
    private var selectionBeforePro: NavItem?

    func open(_ item: NavItem) {
        if item == .commentator, !EntitlementService.shared.canUseAI {
            openPremium()
            return
        }
        if item == .pro, selection != .pro { selectionBeforePro = selection }
        selection = item
    }
    func openPremium() {
        if selection != .pro { selectionBeforePro = selection }
        selection = .pro
    }
    func backFromPro() {
        selection = selectionBeforePro ?? .live
        selectionBeforePro = nil
    }
    func open(fixture: Fixture) { selectedFixture = fixture; selection = .match }
    func open(team: Team) { selectedTeam = team; selection = .teams }
}
