import Foundation

// Tallies the macros of meals the user actually COOKED — a byproduct of the
// "I cooked this" action, never manual logging. Frij isn't a food diary; this
// just celebrates cooking the same way the streak does, in macro form.
@MainActor
@Observable
final class CookedNutritionStore {
    static let shared = CookedNutritionStore()
    private init() { load() }

    struct Entry: Codable {
        let day: String        // yyyy-MM-dd
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    private(set) var entries: [Entry] = []
    private let key = "frij.cookedNutrition.v1"

    /// Record a cooked meal's macros. No-ops when the recipe had no estimate.
    func record(_ nutrition: Nutrition?) {
        guard let n = nutrition else { return }
        let e = Entry(day: Self.dayKey(Date()),
                      calories: n.calories ?? 0, protein: n.protein ?? 0,
                      carbs: n.carbs ?? 0, fat: n.fat ?? 0)
        if e.calories == 0, e.protein == 0, e.carbs == 0, e.fat == 0 { return }
        entries.append(e)
        if entries.count > 400 { entries.removeFirst(entries.count - 400) }  // keep it small
        save()
    }

    struct Totals { var meals: Int; var calories: Int; var protein: Int; var carbs: Int; var fat: Int }

    /// This week's totals, Sunday-anchored to match the streak trail.
    func thisWeek() -> Totals {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        guard let sunday = cal.date(byAdding: .day, value: -(weekday - 1),
                                    to: cal.startOfDay(for: today)) else {
            return Totals(meals: 0, calories: 0, protein: 0, carbs: 0, fat: 0)
        }
        let weekKeys = Set((0..<7).compactMap {
            cal.date(byAdding: .day, value: $0, to: sunday).map(Self.dayKey)
        })
        let week = entries.filter { weekKeys.contains($0.day) }
        return Totals(
            meals: week.count,
            calories: week.reduce(0) { $0 + $1.calories },
            protein: week.reduce(0) { $0 + $1.protein },
            carbs: week.reduce(0) { $0 + $1.carbs },
            fat: week.reduce(0) { $0 + $1.fat })
    }

    private static let df: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()
    private static func dayKey(_ d: Date) -> String { df.string(from: d) }

    private func save() {
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: key) }
    }
    private func load() {
        if let d = UserDefaults.standard.data(forKey: key),
           let e = try? JSONDecoder().decode([Entry].self, from: d) { entries = e }
    }
}
