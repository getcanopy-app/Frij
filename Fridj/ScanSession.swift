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

    // The kitchen page's chosen mode (dinner / dessert / snack / smoothie).
    // Lives here, NOT as @State in PantryView: the pantry tab is built inside
    // `if selectedTab == .bookmarks`, so switching tabs destroys and recreates
    // the view — a @State mealMode would silently snap back to "dinner", and
    // the user would pick Snacks, glance away, return, and cook dinners.
    var mealMode = "dinner"

    // Scan result state — read by ExpandableTabBar to morph from tab bar → found panel
    var scanDetectedItems: [DetectedItem] = []
    var showScanFound = false
    var showScanOverview = false

    // Set by ScanFlowCoordinator when the camera panel is up so the tab bar
    // (in ContentView) can swipe out of view.
    var hidesTabBar = false

    // Just enough to stop accidental double-tap spam. Overlap is already blocked
    // by isCooking and the backend rate-limits per device, so anything longer
    // (this used to be 30s) reads as a broken button, not protection.
    private let cookCooldown: TimeInterval = 5
    private var cookTask: Task<Void, Never>?
    // Observable (unlike a Date comparison) so buttons dim during the cooldown
    // and — crucially — un-dim the moment it ends.
    private(set) var isCoolingDown = false
    private var cooldownTask: Task<Void, Never>?

    // True when neither a generation nor the brief cooldown is in flight.
    var canCook: Bool { !isCooking && !isCoolingDown }

    private func startCooldown() {
        isCoolingDown = true
        cooldownTask?.cancel()
        cooldownTask = Task { [cookCooldown] in
            try? await Task.sleep(nanoseconds: UInt64(cookCooldown * 1_000_000_000))
            guard !Task.isCancelled else { return }
            isCoolingDown = false
        }
    }

    // True when the user is blocked specifically by the free-tier limit.
    var isPremiumGated: Bool {
        !SubscriptionManager.shared.isSubscribed && UsageStore.shared.hasReachedLimit
    }

    /// `mode` is "dinner" (default) or "dessert" — the backend swaps its whole
    /// brief on it. `prioritize` names items about to spoil for "use it up".
    /// Both defaulted so existing callers keep asking for dinners from all of it.
    func cook(ingredients: [String], mode: String = "dinner", prioritize: [String] = [],
              anchored: Bool = false) {
        guard canCook else { return }

        let subMgr = SubscriptionManager.shared
        let usage  = UsageStore.shared

        // Block non-subscribers who've exhausted their free generations.
        if !subMgr.isSubscribed && usage.hasReachedLimit {
            subMgr.showPaywall = true
            return
        }

        isCooking = true
        cookError = nil
        cookTask = Task {
            do {
                let result = try await FrijAPI.recipes(ingredients: ingredients, mode: mode,
                                                       prioritize: prioritize, anchored: anchored)
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
            // Cooldown starts when the generation ENDS, so a slow request
            // doesn't eat into it.
            startCooldown()
        }
    }

    /// Cancel an in-flight generation. Because the credit is only spent on a
    /// real result, cancelling costs nothing — and it skips the cooldown so an
    /// accidental tap isn't also punished with a wait.
    func cancelCook() {
        cookTask?.cancel()
        cookTask = nil
        isCooking = false
        cooldownTask?.cancel()
        isCoolingDown = false
    }
}
