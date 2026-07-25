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
    ///
    /// `cooked` is the strongest positive signal (you cook what you want),
    /// `favorites` a lighter one (saved on a whim), `disliked` a soft avoid.
    static func brief(favorites: [Recipe], cooked: [Recipe] = [], disliked: [String] = []) -> String? {
        // Positives, cooked first so it wins ties, deduped by name across both.
        var seen = Set<String>()
        let cookedNames = uniqueNames(cooked, into: &seen)
        let savedNames = uniqueNames(favorites, into: &seen)

        // Need at least a little positive history before we personalize at all.
        guard cookedNames.count + savedNames.count >= minSaved else { return nil }

        var lines: [String] = []

        // 1a) Cooked dishes — the highest-signal input, called out as such.
        if !cookedNames.isEmpty {
            lines.append("Dishes they've actually cooked (their strongest signal): \(cookedNames.prefix(10).joined(separator: ", ")).")
        }
        // 1b) Saved-but-not-yet-cooked dishes — a softer lean.
        if !savedNames.isEmpty {
            lines.append("Dishes they've saved: \(savedNames.prefix(10).joined(separator: ", ")).")
        }

        // 2) Ingredients they reach for — frequent across cooked + saved "uses".
        let topIngredients = frequentIngredients(in: cooked + favorites, top: 8)
        if !topIngredients.isEmpty {
            lines.append("Ingredients they reach for often: \(topIngredients.joined(separator: ", ")).")
        }

        // 3) Effort lean — quick things or involved ones?
        if let lean = effortLean(in: cooked + favorites) {
            lines.append(lean)
        }

        // 4) Soft avoid — dishes they've waved off.
        let avoids = disliked.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.prefix(8)
        if !avoids.isEmpty {
            lines.append("Dishes they passed on — show fewer like these: \(avoids.joined(separator: ", ")).")
        }

        return lines.isEmpty ? nil : lines.joined(separator: " ")
    }

    /// Names from recipes, skipping empties and anything already seen (so cooked
    /// dishes aren't repeated in the saved list).
    private static func uniqueNames(_ recipes: [Recipe], into seen: inout Set<String>) -> [String] {
        var out: [String] = []
        for r in recipes {
            let key = r.name.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(r.name)
        }
        return out
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
