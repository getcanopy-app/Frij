import Foundation

// The one place that decides "is this ingredient in the fridge?" — used at
// import time and, crucially, LIVE at render time: a recipe's have/need split
// must reflect the pantry as it is NOW, not as it was when the recipe was
// created (buy the tortillas and the recipe should notice).
@MainActor
enum PantryMatch {
    /// Whole-word match of any pantry item inside the ingredient text, so
    /// quantity-carrying strings ("1 cup heavy cream") still match the pantry's
    /// "heavy cream". Tolerates simple plural s/es on the pantry side.
    static func has(_ ingredient: String) -> Bool {
        let pantry = PantryStore.shared.items.map(\.name)   // stored lowercased
        let hay = " " + ingredient.lowercased()
            .replacingOccurrences(of: ",", with: " ") + " "
        return pantry.contains { item in
            hay.contains(" \(item) ") || hay.contains(" \(item)s ") || hay.contains(" \(item)es ")
        }
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
