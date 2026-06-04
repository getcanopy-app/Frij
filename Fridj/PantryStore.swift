//
//  PantryStore.swift
//  Fridj
//

import Foundation
import Observation

@Observable
final class PantryStore {
    static let shared = PantryStore()

    private(set) var items: [PantryItem] = []

    private let storageKey = "frij.pantry.v1"
    private let didSeedKey = "frij.pantry.didSeedDefaults.v1"
    private let defaults: UserDefaults

    /// The items every kitchen has. Pre-loaded on first launch only.
    /// Removable like any other item — once removed, never re-added.
    static let defaultItems: [String] = [
        "salt",
        "black pepper",
        "olive oil",
        "sugar",
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(from: defaults, key: storageKey)
        seedDefaultsIfNeeded()
    }

    // MARK: First-launch seeding

    /// Adds the basic kitchen items the first time the app ever opens.
    /// We use a separate "did seed" flag instead of "is pantry empty" so that
    /// a user who explicitly clears their pantry doesn't get defaults reinjected.
    private func seedDefaultsIfNeeded() {
        guard !defaults.bool(forKey: didSeedKey) else { return }
        let now = Date()
        for name in Self.defaultItems where !items.contains(where: { $0.name == name }) {
            items.append(PantryItem(name: name, source: .default, now: now))
        }
        defaults.set(true, forKey: didSeedKey)
        save()
    }

    // MARK: Existing API

    var allNames: [String] { items.map(\.name) }

    func contains(_ name: String) -> Bool {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        return items.contains { $0.name == n }
    }

    func addLocal(name: String, source: PantryItem.Source) {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { return }
        if let idx = items.firstIndex(where: { $0.name == n }) {
            items[idx].lastSeenAt = Date()
            save()
            return
        }
        items.append(PantryItem(name: n, source: source))
        save()
    }

    @discardableResult
    func addValidated(name: String) async -> ValidationResult {
        do {
            let result = try await FrijAPI.validate(name: name)
            if result.valid, let normalized = result.normalized, !normalized.isEmpty {
                addLocal(name: normalized, source: .manual)
            }
            return result
        } catch {
            addLocal(name: name, source: .manual)
            return ValidationResult(valid: true, normalized: name, reason: nil)
        }
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        save()
    }

    func remove(name: String) {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        items.removeAll { $0.name == n }
        save()
    }

    @discardableResult
    func mergeScan(_ detected: [DetectedItem]) -> [String] {
        let now = Date()
        var newlyAdded: [String] = []
        for d in detected {
            let n = d.item.lowercased().trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { continue }
            if let idx = items.firstIndex(where: { $0.name == n }) {
                items[idx].lastSeenAt = now
            } else {
                items.append(PantryItem(name: n, source: .scanned, now: now))
                newlyAdded.append(n)
            }
        }
        save()
        return newlyAdded
    }

    func clearAll() {
        items.removeAll()
        save()
    }

    // MARK: persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(items)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("PantryStore save failed:", error)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> [PantryItem] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PantryItem].self, from: data)) ?? []
    }
}
