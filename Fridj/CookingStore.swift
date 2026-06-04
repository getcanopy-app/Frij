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
    }

    func hasCooked(on date: Date) -> Bool {
        cookedDates.contains(Self.dateKey(for: date))
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
