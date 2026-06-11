import Foundation

struct GroceryItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var isChecked: Bool

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isChecked = false
    }
}

@MainActor @Observable
final class GroceryStore {
    static let shared = GroceryStore()
    private let key = "com.frij.groceryList"

    var items: [GroceryItem] = []

    var hasItems: Bool { !items.isEmpty }
    var uncheckedCount: Int { items.filter { !$0.isChecked }.count }

    private init() { load() }

    func add(_ names: [String]) {
        for name in names {
            let normalized = name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !items.contains(where: { $0.name.lowercased() == normalized }) else { continue }
            items.append(GroceryItem(name: name.trimmingCharacters(in: .whitespaces)))
        }
        save()
    }

    func toggle(_ item: GroceryItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].isChecked.toggle()
        save()
    }

    func remove(_ item: GroceryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearChecked() {
        items.removeAll { $0.isChecked }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([GroceryItem].self, from: data)
        else { return }
        items = saved
    }
}
