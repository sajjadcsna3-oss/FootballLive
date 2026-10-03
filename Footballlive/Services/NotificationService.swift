import Foundation
import UserNotifications
import Combine

@MainActor final class NotificationService: ObservableObject {
    static let shared = NotificationService()
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private let center = UNUserNotificationCenter.current()
    func refreshStatus() async { authorizationStatus = await center.notificationSettings().authorizationStatus }
    func refreshDeliveredMetrics() async {
        let delivered = await center.deliveredNotifications()
        for notification in delivered { UsageMetricsService.shared.recordAlertDelivered(id: notification.request.identifier) }
    }
    @discardableResult
    func requestAuthorization() async throws -> Bool {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshStatus()
        return granted
    }
    func scheduleStartingSoon(for fixture: Fixture) async throws {
        guard let kickoff = fixture.kickoff else { return }
        let content = UNMutableNotificationContent(); content.title = L10n.text("Match starting soon"); content.body = L10n.text("%@ vs %@ starts in 10 minutes.", fixture.homeTeam.name, fixture.awayTeam.name); content.sound = .default
        content.userInfo = ["homeTeamID": fixture.homeTeam.id, "awayTeamID": fixture.awayTeam.id]
        let date = kickoff.addingTimeInterval(-600); guard date > Date() else { return }
        try await center.add(UNNotificationRequest(identifier: "kickoff-\(fixture.id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date), repeats: false)))
    }
    func scheduleWeeklyRecap(enabled: Bool) async throws {
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-recap"]); guard enabled else { return }
        let content = UNMutableNotificationContent(); content.title = L10n.text("Your weekly football recap"); content.body = L10n.text("Open Tempo to catch up on followed teams."); content.sound = .default
        var schedule = DateComponents()
        schedule.hour = 20
        schedule.weekday = 1
        try await center.add(UNNotificationRequest(identifier: "weekly-recap", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: schedule, repeats: true)))
    }
    func reconcileSavedPreferences() async {
        await refreshStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }
        let enabled = Set(UserDefaults.standard.stringArray(forKey: "enabledAlerts") ?? [])
        try? await scheduleWeeklyRecap(enabled: enabled.contains(AlertKind.recap.rawValue))
    }
    func cancelStartingSoon(forTeamID teamID: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.filter { request in
            request.identifier.hasPrefix("kickoff-") &&
            ((request.content.userInfo["homeTeamID"] as? String) == teamID ||
             (request.content.userInfo["awayTeamID"] as? String) == teamID)
        }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
    func deliver(title: String, body: String, id: String) async throws {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        UsageMetricsService.shared.recordAlertDelivered(id: id)
    }
}
