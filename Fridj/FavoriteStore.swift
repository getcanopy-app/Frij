//
//  FavoritesStore.swift
//  Fridj
//
//  Persists user-favorited recipes locally. Same pattern as PantryStore.
//  When server-side accounts arrive later, this becomes a sync target.
//

import Foundation
import Observation

@Observable
final class FavoritesStore {
    static let shared = FavoritesStore()

    private(set) var recipes: [Recipe] = []

    private let storageKey = "frij.favorites.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.recipes = Self.load(from: defaults, key: storageKey)
    }

    func isFavorite(_ recipe: Recipe) -> Bool {
        recipes.contains { $0.id == recipe.id }
    }

    /// Toggle. Returns the new state (true = now favorited).
    @discardableResult
    func toggle(_ recipe: Recipe) -> Bool {
        if let idx = recipes.firstIndex(where: { $0.id == recipe.id }) {
            recipes.remove(at: idx)
            save()
            return false
        } else {
            recipes.insert(recipe, at: 0)  // newest first
            save()
            return true
        }
    }

    func remove(_ recipe: Recipe) {
        recipes.removeAll { $0.id == recipe.id }
        save()
    }

    func clearAll() {
        recipes.removeAll()
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(recipes)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("FavoritesStore save failed:", error)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> [Recipe] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Recipe].self, from: data)) ?? []
    }
}
