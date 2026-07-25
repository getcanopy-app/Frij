import Foundation

// Turns what the user has already saved into a compact "taste brief" the recipe
// brain can lean on — the first step toward Frij feeling like it *knows* you.
//
// We deliberately derive this from signals that already exist (saved recipes),
// so there's no new tracking UI and nothing to clutter the app. The single
// highest-signal input is simply the NAMES of dishes they saved: a model reads
// "Creamy Garlic Pasta, Shrimp Tacos, Shakshuka" and infers the taste instantly.
// We add the ingredients they reach for and a quick-vs-involved lean on top.
enum TasteProfile {

    // Below this many saved recipes there isn't enough signal to personalize
    // honestly — better to behave exactly as before than to guess from one save.
    private static let minSaved = 2

    /// A short natural-language brief, or nil when there's too little to go on.
    /// Sent to the backend like `cuisine` — a soft lean, never a hard rule.
    static func brief(favorites: [Recipe]) -> String? {
        guard favorites.count >= minSaved else { return nil }

        var lines: [String] = []

        // 1) The dishes themselves — most recent first, capped so the brief stays
        //    tight. This is the part the model reads taste from most directly.
        let names = favorites.prefix(12).map(\.name).filter { !$0.isEmpty }
        if !names.isEmpty {
            lines.append("Dishes they've saved before: \(names.joined(separator: ", ")).")
        }

        // 2) Ingredients they reach for — most frequent across the "uses" of saved
        //    recipes. Reveals staples and leanings the dish names alone might miss.
        let topIngredients = frequentIngredients(in: favorites, top: 8)
        if !topIngredients.isEmpty {
            lines.append("Ingredients they reach for often: \(topIngredients.joined(separator: ", ")).")
        }

        // 3) Effort lean — do they save quick things or involved ones?
        if let lean = effortLean(in: favorites) {
            lines.append(lean)
        }

        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    // MARK: - Signals

    private static func frequentIngredients(in favorites: [Recipe], top: Int) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []   // preserve first-seen order for stable ties
        for recipe in favorites {
            for raw in recipe.uses {
                let name = raw.lowercased().trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { continue }
                if counts[name] == nil { order.append(name) }
                counts[name, default: 0] += 1
            }
        }
        // Only surface ingredients that recur — a one-off "use" isn't a pattern.
        let recurring = order.filter { (counts[$0] ?? 0) >= 2 }
        let sorted = recurring.sorted { (counts[$0] ?? 0) > (counts[$1] ?? 0) }
        return Array(sorted.prefix(top))
    }

    /// "prefers quick meals" / "doesn't mind a longer cook" — or nil if unclear.
    private static func effortLean(in favorites: [Recipe]) -> String? {
        let minutes = favorites.compactMap { parseMinutes($0.cookTime) }
        guard minutes.count >= minSaved else { return nil }
        let avg = minutes.reduce(0, +) / minutes.count
        if avg <= 25 { return "They lean toward quick meals (around \(avg) min)." }
        if avg >= 45 { return "They're happy to spend time cooking (often \(avg)+ min)." }
        return nil
    }

    /// Best-effort minutes from strings like "25 min", "1 hr 10 min", "45m".
    private static func parseMinutes(_ text: String) -> Int? {
        let lower = text.lowercased()
        let nums = lower.split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        guard !nums.isEmpty else { return nil }
        if lower.contains("hr") || lower.contains("hour") {
            let hours = nums[0]
            let mins = nums.count > 1 ? nums[1] : 0
            return hours * 60 + mins
        }
        return nums[0]
    }
}
