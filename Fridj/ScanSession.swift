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
    /// brief on it. Defaulted so existing callers keep asking for dinners.
    func cook(ingredients: [String], mode: String = "dinner") {
        guard canCook else { return }

        let subMgr = SubscriptionManager.shared
        let usage  = UsageStore.shared

        // Block non-subscribers who've exhausted their free generations.
        if !subMgr.isSubscribed && usage.hasReachedLimit {
            subMgr.showPaywall = true
            return
        }

        // Record usage before the API call so a crash mid-request still counts.
        if !subMgr.isSubscribed {
            usage.recordGeneration()
        }

        lastCookTime = Date()
        isCooking = true
        cookError = nil
        Task {
            do {
                let result = try await FrijAPI.recipes(ingredients: ingredients, mode: mode)
                recipes = result
                showRecipes = true
            } catch {
                cookError = error.localizedDescription
            }
            isCooking = false
        }
    }
}
