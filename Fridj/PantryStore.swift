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
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = Self.load(from: defaults, key: storageKey)
    }

    var allNames: [String] { items.map(\.name) }

    func contains(_ name: String) -> Bool {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        return items.contains { $0.name == n }
    }

    /// Local add — used internally and by scan merge. No validation, no network.
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

    /// User-typed add. Validates against the backend first.
    /// Returns the validation result so the UI can show rejection reasons.
    @discardableResult
    func addValidated(name: String) async -> ValidationResult {
        do {
            let result = try await FrijAPI.validate(name: name)
            if result.valid, let normalized = result.normalized, !normalized.isEmpty {
                addLocal(name: normalized, source: .manual)
            }
            return result
        } catch {
            // Network error — fail open. Better to accept the item than block the user.
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
