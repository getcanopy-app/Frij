import Foundation

// Drains links/captions stashed by the ShareImport extension (App Group inbox)
// and turns each into a saved recipe. Runs on every foreground; deliberately
// silent — the imported meal simply appears in Saved, pantry-cross-checked
// like any pasted import.
@MainActor
enum ImportInbox {
    private static let appGroupID = "group.com.hellofrij.frij"
    private static let inboxKey = "frij.importInbox"
    private static var isProcessing = false

    static func processPending() async {
        guard !isProcessing,
              let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let pending = defaults.stringArray(forKey: inboxKey) ?? []
        guard !pending.isEmpty else { return }

        isProcessing = true
        defaults.removeObject(forKey: inboxKey)
        defer { isProcessing = false }

        for entry in pending {
            // Failures drop silently: the share moment is long past, so there's
            // no good surface to complain on. The paste-a-link sheet remains
            // the retry path.
            if let recipe = try? await FrijAPI.importRecipe(entry),
               !FavoritesStore.shared.isFavorite(recipe) {
                _ = FavoritesStore.shared.toggle(recipe)
            }
        }
    }
}
