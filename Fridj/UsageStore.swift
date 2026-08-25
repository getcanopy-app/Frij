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
    private let bonusKey = "frij.usage.v1.bonusGenerations"
    private let codeKey  = "frij.usage.v1.redeemedCode"
    private(set) var generationsUsed: Int

    // Extra free generations granted by redeeming a creator's referral code.
    // Adds to the free limit (never expires locally). One code per install:
    // `redeemedCode` gates re-redeeming so a follower can't farm the bonus.
    private(set) var bonusGenerations: Int
    private(set) var redeemedCode: String?
    var hasRedeemedCode: Bool { redeemedCode != nil }

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
        bonusGenerations = UserDefaults.standard.integer(forKey: bonusKey)
        redeemedCode = UserDefaults.standard.string(forKey: codeKey)
        #if DEBUG
        // Debug builds default to admin-ON so running from Xcode never hits the
        // free limit — no 7-tap needed, even on a fresh install. An explicit
        // toggle-off is still respected (stored value wins over the default), so
        // the paywall/free-tier flow stays testable by tapping admin off.
        // Release builds never see this: isAdmin is a hard-compiled `false`.
        isAdmin = UserDefaults.standard.object(forKey: adminKey) as? Bool ?? true
        #endif
    }

    var remaining: Int { isAdmin ? 9999 : max(0, Self.freeLimit + bonusGenerations - generationsUsed) }
    var hasReachedLimit: Bool { isAdmin ? false : (generationsUsed >= Self.freeLimit + bonusGenerations) }

    /// Grant a creator code's bonus generations, once per install. Returns false
    /// if a code was already redeemed on this device (prevents farming).
    @discardableResult
    func applyCreatorBonus(_ meals: Int, code: String) -> Bool {
        guard redeemedCode == nil, meals > 0 else { return false }
        redeemedCode = code
        bonusGenerations += meals
        UserDefaults.standard.set(redeemedCode, forKey: codeKey)
        UserDefaults.standard.set(bonusGenerations, forKey: bonusKey)
        return true
    }

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
