import Foundation

// Recognizes when a hand-picked selection is really a smoothie/dessert in
// disguise, so the kitchen can nudge the user to the right mode instead of
// forcing a bad dinner. This is the CLIENT half of the guava fix; the backend
// prompt is the honesty valve for everything that slips past.
enum SweetLean {
    // Fruits whose natural home is a smoothie or dessert. (Savoury-flexible
    // fruits — pineapple, mango, peach, apple — are deliberately NOT here: they
    // can anchor a real dinner, and the backend keeps them honest.)
    private static let fruit = [
        "guava", "banana", "strawberr", "raspberr", "blackberr", "blueberr",
        "berries", "berry", "melon", "watermelon", "cantaloupe", "grape",
        "cherries", "cherry",
    ]

    // Dessert-only items — never a savoury dinner, ever.
    private static let dessertOnly = [
        "nutella", "chocolate", "cocoa", "jam", "jelly", "marmalade",
        "marshmallow", "caramel", "frosting", "condensed milk", "cookie",
        "brownie", "cake", "ice cream", "whipped cream", "syrup", "fudge",
        "toffee", "sprinkles", "graham",
    ]

    // Neutral pantry staples that don't decide savoury-vs-sweet on their own,
    // so a selection of just these + one fruit still reads as "sweet".
    private static let neutral = [
        "salt", "pepper", "oil", "sugar", "water", "vanilla", "cinnamon",
        "flour", "butter", "milk", "egg", "ice", "honey", "yogurt", "oats",
    ]

    private static func isSweet(_ n: String) -> Bool {
        (fruit + dessertOnly).contains { n.contains($0) }
    }

    /// For a HAND-PICKED selection: the modes to suggest if it's dominated by
    /// sweet ingredients, or nil to just cook dinner. Returns nil the moment a
    /// real savoury ingredient is in the mix (guava + chicken → make dinner,
    /// the backend glazes the chicken).
    static func suggestion(for items: [String]) -> [String]? {
        let substantial = items
            .map { $0.lowercased() }
            .filter { name in !neutral.contains { name.contains($0) } }
        guard !substantial.isEmpty else { return nil }

        let sweet = substantial.filter(isSweet)
        let savoury = substantial.filter { !isSweet($0) }
        // Dominated = at least one sweet item and NO substantial savoury one.
        guard !sweet.isEmpty, savoury.isEmpty else { return nil }

        let hasFruit = sweet.contains { n in fruit.contains { n.contains($0) } }
        // Fruit shines in smoothies AND desserts; a jar of Nutella is dessert.
        return hasFruit ? ["smoothie", "dessert"] : ["dessert"]
    }

    /// Human label for the nudge, from the first sweet item picked.
    static func headline(for items: [String]) -> String {
        let name = items.first { isSweet($0.lowercased()) } ?? "That"
        let nice = name.prefix(1).uppercased() + name.dropFirst().lowercased()
        return "\(nice) shines best in"
    }
}
