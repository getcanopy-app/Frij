import Foundation

// Owns the recipe-generation task so it survives tab switches.
// ScanView reads from this; the Task runs on the main actor and
// persists even if ScanView is torn down and recreated.
@MainActor
@Observable
final class ScanSession {
    static let shared = ScanSession()
    private init() {}

    var isCooking = false
    var recipes: [Recipe] = []
    var cookError: String?
    var showRecipes = false

    // Scan result state — read by ExpandableTabBar to morph from tab bar → found panel
    var scanDetectedItems: [DetectedItem] = []
    var showScanFound = false
    var showScanOverview = false

    // Set by ScanFlowCoordinator when the camera panel is up so the tab bar
    // (in ContentView) can swipe out of view.
    var hidesTabBar = false

    private var lastCookTime: Date?
    private let cookCooldown: TimeInterval = 30
    private var cookTask: Task<Void, Never>?

    // True when the cooldown hasn't expired yet (separate from subscription gate).
    var canCook: Bool {
        guard !isCooking else { return false }
        guard let last = lastCookTime else { return true }
        return Date().timeIntervalSince(last) >= cookCooldown
    }

    // True when the user is blocked specifically by the free-tier limit.
    var isPremiumGated: Bool {
        !SubscriptionManager.shared.isSubscribed && UsageStore.shared.hasReachedLimit
    }

    /// `mode` is "dinner" (default) or "dessert" — the backend swaps its whole
    /// brief on it. `prioritize` names items about to spoil for "use it up".
    /// Both defaulted so existing callers keep asking for dinners from all of it.
    func cook(ingredients: [String], mode: String = "dinner", prioritize: [String] = []) {
        guard canCook else { return }

        let subMgr = SubscriptionManager.shared
        let usage  = UsageStore.shared

        // Block non-subscribers who've exhausted their free generations.
        if !subMgr.isSubscribed && usage.hasReachedLimit {
            subMgr.showPaywall = true
            return
        }

        lastCookTime = Date()
        isCooking = true
        cookError = nil
        cookTask = Task {
            do {
                let result = try await FrijAPI.recipes(ingredients: ingredients, mode: mode, prioritize: prioritize)
                try Task.checkCancellation()
                // Spend the credit only once real recipes are in hand, so a
                // cancel or a failed request never costs a free idea.
                if !subMgr.isSubscribed { usage.recordGeneration() }
                recipes = result
                // Bank the batch so the next "more options" excludes it, and so
                // it survives in the "Recently generated" list.
                RecipeHistoryStore.shared.record(result)
                showRecipes = true
            } catch {
                // Cancelling throws too (URLError.cancelled / CancellationError);
                // don't surface that as an error — and no credit was spent.
                if !Task.isCancelled { cookError = error.localizedDescription }
            }
            isCooking = false
            cookTask = nil
        }
    }

    /// Cancel an in-flight generation. Because the credit is only spent on a
    /// real result, cancelling costs nothing — and it clears the cooldown so an
    /// accidental tap isn't also punished with a 30s wait.
    func cancelCook() {
        cookTask?.cancel()
        cookTask = nil
        isCooking = false
        lastCookTime = nil
    }
}
