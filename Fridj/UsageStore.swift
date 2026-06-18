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
    private(set) var generationsUsed: Int

    private init() {
        generationsUsed = UserDefaults.standard.integer(forKey: "frij.usage.v1.generationsUsed")
    }

    var remaining: Int { max(0, Self.freeLimit - generationsUsed) }
    var hasReachedLimit: Bool { generationsUsed >= Self.freeLimit }

    func recordGeneration() {
        generationsUsed += 1
        UserDefaults.standard.set(generationsUsed, forKey: key)
    }
}
