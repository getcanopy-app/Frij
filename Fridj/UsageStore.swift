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

    #if DEBUG
    private(set) var isAdmin: Bool
    #else
    // The admin override is a debug-only testing convenience. In release
    // builds it is hard-compiled to false so the free-tier limit can never
    // be bypassed in production — a stale UserDefaults flag is ignored too.
    let isAdmin = false
    #endif

    private init() {
        generationsUsed = UserDefaults.standard.integer(forKey: key)
        #if DEBUG
        isAdmin = UserDefaults.standard.bool(forKey: adminKey)
        #endif
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
    // Debug-only: a no-op in release builds (see isAdmin above), so the hidden
    // gesture cannot unlock unlimited free generations in the shipped app.
    func toggleAdmin() {
        #if DEBUG
        isAdmin.toggle()
        UserDefaults.standard.set(isAdmin, forKey: adminKey)
        #endif
    }
}
