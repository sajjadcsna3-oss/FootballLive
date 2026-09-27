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
    func requestAuthorization() async throws { _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]); await refreshStatus() }
    func scheduleStartingSoon(for fixture: Fixture) async throws {
        guard let kickoff = fixture.kickoff else { return }
        let content = UNMutableNotificationContent(); content.title = L10n.text("Match starting soon"); content.body = L10n.text("%@ vs %@ starts in 10 minutes.", fixture.homeTeam.name, fixture.awayTeam.name); content.sound = .default
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
    func deliver(title: String, body: String, id: String) async throws {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
        UsageMetricsService.shared.recordAlertDelivered(id: id)
    }
}
