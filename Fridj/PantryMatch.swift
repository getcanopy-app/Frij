import Foundation

// The one place that decides "is this ingredient in the fridge?" — used at
// import time and, crucially, LIVE at render time: a recipe's have/need split
// must reflect the pantry as it is NOW, not as it was when the recipe was
// created (buy the tortillas and the recipe should notice).
@MainActor
enum PantryMatch {
    /// Whole-word match of any pantry item inside the ingredient text, so
    /// quantity-carrying strings ("1 cup heavy cream") still match the pantry's
    /// "heavy cream". Plurals are tolerated in BOTH directions — pantry "eggs"
    /// must match "2 egg yolks" (singular in the phrase), and pantry "tomato"
    /// must match "2 cups cherry tomatoes" (plural in the phrase).
    static func has(_ ingredient: String) -> Bool {
        let hay = " " + ingredient.lowercased()
            .replacingOccurrences(of: ",", with: " ") + " "
        return PantryStore.shared.items.contains { item in
            forms(of: item.name).contains { hay.contains(" \($0) ") }
        }
    }

    /// Display-time split of "2 cups cherry tomatoes" into (name: "cherry
    /// tomatoes", amount: "2 cups"). Purely cosmetic — storage and matching
    /// still use the full string; the real {name, amount} schema separation is
    /// the 1.0.2 data work. Only fires when the string LEADS with a quantity,
    /// so plain names pass through untouched.
    static func displaySplit(_ text: String) -> (name: String, amount: String?) {
        let s = text.trimmingCharacters(in: .whitespaces)
        let pattern = "^((?:\\d[\\d/.,]*|[½⅓¼¾⅔])(?:\\s?(?:g|kg|mg|ml|l|cups?|tbsp|tablespoons?|tsp|teaspoons?|lbs?|pounds?|oz|ounces?|cloves?|cans?|slices?|sticks?|pinches?|pinch|pieces?|bunch(?:es)?))?)\\s+(.+)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              let amountRange = Range(match.range(at: 1), in: s),
              let nameRange = Range(match.range(at: 2), in: s)
        else { return (s, nil) }
        return (String(s[nameRange]), String(s[amountRange]))
    }

    /// Plural/singular variants of a pantry name for whole-word matching.
    private static func forms(of raw: String) -> [String] {
        let name = raw.lowercased().trimmingCharacters(in: .whitespaces)
        var forms = [name, name + "s", name + "es"]
        if name.hasSuffix("ies") { forms.append(String(name.dropLast(3)) + "y") }
        if name.hasSuffix("es") { forms.append(String(name.dropLast(2))) }
        if name.hasSuffix("s") { forms.append(String(name.dropLast())) }
        return forms
    }

    /// Split an ingredient list into (in your fridge, still to buy), preserving
    /// order within each group.
    static func partition(_ ingredients: [String]) -> (have: [String], need: [String]) {
        var have: [String] = []
        var need: [String] = []
        for item in ingredients {
            if has(item) { have.append(item) } else { need.append(item) }
        }
        return (have, need)
    }
}
