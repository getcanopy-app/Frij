import Foundation

/// The core effects of the "I cooked this" action, shared by EVERY screen that
/// offers it (Recipes tab, Home's recent ideas, …) so cooking always counts the
/// same way — no matter where the user tapped it. Consumes the perishables the
/// recipe used, logs the streak, tallies macros, records the taste signal, and
/// fires the celebration. Returns the perishables removed, for an optional undo.
///
/// This exists because Home was calling only `selectedRecipe = nil` and never
/// logging the cook — so cooking from a Home card silently gave no streak.
@MainActor
enum CookLog {
    /// The cookbook entry created by the most recent cook, so the screen the
    /// user is standing on can offer a photo for THAT meal.
    private(set) static var lastEntry: CookbookStore.Entry?

    @discardableResult
    static func record(_ recipe: Recipe) -> [String] {
        // Strongest taste signal — the dish itself, not just the date.
        TasteSignalsStore.shared.logCooked(recipe)

        // Uses + needs: an ingredient bought since (stored under needs) is in the
        // pantry now, so cooking should consume it too. Only perishables leave —
        // staples (oil, salt) are immortal.
        let pantry = PantryStore.shared
        let removed = (recipe.uses + recipe.needs).filter {
            pantry.contains($0) && PantryCategory.classify($0).isPerishable
        }
        for name in removed { pantry.remove(name: name) }

        // Cooking always counts — streak and celebration never depend on whether
        // pantry items happened to match (substitutions, unlogged grocery runs).
        CookingStore.shared.logToday()
        CookedNutritionStore.shared.record(recipe.nutrition)
        // Every cook lands in the cookbook, photo or no photo.
        lastEntry = CookbookStore.shared.record(recipe)
        HealthLog.shared.log(recipe)  // no-op unless turned on in Profile
        // Occasionally offer the invite after a cook — the one moment the user
        // has just succeeded. Rate-limited inside; see InviteNudge.
        InviteNudge.shared.recordCook()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            CelebrationCoordinator.shared.show(streak: CookingStore.shared.currentStreak)
        }
        return removed
    }
}
