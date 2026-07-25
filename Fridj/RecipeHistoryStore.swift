import Foundation
import Observation

// A rolling record of every dinner/dessert Frij has generated. Serves two jobs
// with one store:
//   1. Anti-repeat — its recent names are sent to the backend as "don't return
//      these again," so hitting "more options" actually gives fresh ideas
//      instead of burning a credit on the same meal.
//   2. Never-lose-it — it backs the "Recently generated" section, so a meal you
//      saw and liked but didn't heart isn't gone the moment you regenerate.
// Capped and local (a sync target when accounts arrive).
@MainActor @Observable
final class RecipeHistoryStore {
    static let shared = RecipeHistoryStore()

    private(set) var recipes: [Recipe] = []   // most-recent first

    private let key = "frij.history.v1"
    private let defaults: UserDefaults
    private let cap = 40

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.recipes = Self.load(from: defaults, key: key)
    }

    /// Record a freshly generated batch. Newest first; a dish that recurs moves
    /// to the top rather than duplicating.
    func record(_ batch: [Recipe]) {
        // Insert in reverse so the batch's own order is preserved at the front.
        for recipe in batch.reversed() {
            recipes.removeAll { $0.id == recipe.id }
            recipes.insert(recipe, at: 0)
        }
        if recipes.count > cap { recipes = Array(recipes.prefix(cap)) }
        save()
    }

    /// The most-recent dish names — the "don't repeat these" set for the backend.
    func recentNames(limit: Int) -> [String] {
        Array(recipes.prefix(limit).map(\.name))
    }

    func clear() {
        recipes = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(recipes) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> [Recipe] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Recipe].self, from: data)) ?? []
    }
}
