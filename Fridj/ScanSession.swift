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

    private var lastCookTime: Date?
    private let cookCooldown: TimeInterval = 30

    // True when the user is allowed to request new recipes.
    var canCook: Bool {
        guard !isCooking else { return false }
        guard let last = lastCookTime else { return true }
        return Date().timeIntervalSince(last) >= cookCooldown
    }

    func cook(ingredients: [String]) {
        guard canCook else { return }
        lastCookTime = Date()
        isCooking = true
        cookError = nil
        Task {
            do {
                let result = try await FrijAPI.recipes(ingredients: ingredients)
                recipes = result
                showRecipes = true
            } catch {
                cookError = error.localizedDescription
            }
            isCooking = false
        }
    }
}
