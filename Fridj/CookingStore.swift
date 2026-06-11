import Foundation

@MainActor
@Observable
final class CookingStore {
    static let shared = CookingStore()
    private init() { load() }

    private(set) var cookedDates: Set<String> = []
    private let key = "frij.cooking.v1"

    func logToday() {
        cookedDates.insert(Self.dateKey(for: Date()))
        save()
        NotificationScheduler.shared.scheduleStreakReminder()
    }

    func hasCooked(on date: Date) -> Bool {
        cookedDates.contains(Self.dateKey(for: date))
    }

    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var date = Date()
        if !hasCooked(on: date) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: date) else { return 0 }
            date = yesterday
        }
        while hasCooked(on: date) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    private static func dateKey(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func save() {
        UserDefaults.standard.set(Array(cookedDates), forKey: key)
    }

    private func load() {
        cookedDates = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
}
