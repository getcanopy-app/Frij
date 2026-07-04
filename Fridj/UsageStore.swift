import Foundation

// Tracks free-tier recipe generation attempts.
// This is intentionally a soft limit (resets on reinstall) — the
// subscription gate is in SubscriptionManager which uses StoreKit's
// cryptographically verified state and can't be cleared locally.
@MainActor @Observable
final class UsageStore {
    static let shared = UsageStore()
    static let freeLimit = 3

    private let key = "frij.usage.v1.generationsUsed"
    private let adminKey = "frij.usage.v1.isAdmin"
    private(set) var generationsUsed: Int
    private(set) var isAdmin: Bool

    private init() {
        generationsUsed = UserDefaults.standard.integer(forKey: "frij.usage.v1.generationsUsed")
        isAdmin = UserDefaults.standard.bool(forKey: "frij.usage.v1.isAdmin")
    }

    var remaining: Int { isAdmin ? 9999 : max(0, Self.freeLimit - generationsUsed) }
    var hasReachedLimit: Bool { isAdmin ? false : (generationsUsed >= Self.freeLimit) }

    func recordGeneration() {
        // Admins don't consume the counter — unlimited scans for whitelisted devices.
        guard !isAdmin else { return }
        generationsUsed += 1
        UserDefaults.standard.set(generationsUsed, forKey: key)
    }

    // Toggled by a hidden 7-tap gesture on the "About you" title in ProfileView.
    func toggleAdmin() {
        isAdmin.toggle()
        UserDefaults.standard.set(isAdmin, forKey: adminKey)
    }
}
