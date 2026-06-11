import Foundation
import UserNotifications

final class NotificationScheduler {
    static let shared = NotificationScheduler()
    private init() {}

    private let streakReminderID = "frij.reminder.streak"

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Cancel any pending streak reminder and schedule a new one 48h from now.
    /// Call this after every cook and on app launch.
    func scheduleStreakReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [streakReminderID])

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized ||
                  settings.authorizationStatus == .provisional else { return }

            let content = UNMutableNotificationContent()
            content.title = "Time to cook tonight?"
            content.body = "You haven't cooked in a couple days. Check what's in your fridge!"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 48 * 3600, repeats: false)
            let request = UNNotificationRequest(
                identifier: self.streakReminderID,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
