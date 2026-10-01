import StoreKit

// All subscription state lives here. isSubscribed is ALWAYS derived
// from StoreKit's cryptographically-signed JWS transactions — never from
// a UserDefaults flag that could be flipped or patched.
@MainActor @Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // Must match product IDs configured in App Store Connect.
    static let monthlyID = "com.frij.plus.monthly"
    static let annualID  = "com.frij.plus.annual"

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var isPurchasing = false

    // Frij+ time we granted ourselves for hitting an invite milestone. Kept
    // SEPARATE from isSubscribed on purpose: that property's guarantee is that
    // it reflects StoreKit and nothing else, and this is our own perk, not a
    // purchase. A date rather than a flag, so it keeps working offline and
    // expires by itself.
    //
    // Cached locally because the server is the source of truth but must not be
    // a dependency — losing network shouldn't revoke a week someone earned.
    private static let grantKey = "frij.plus.grantedUntil"
    private(set) var plusGrantedUntil: Date? = UserDefaults.standard
        .object(forKey: grantKey) as? Date

    /// Does the user have Frij+ right now, by purchase OR by invite grant?
    /// This is what feature gates should ask. `isSubscribed` alone answers a
    /// narrower question: did they pay.
    var hasPlus: Bool {
        if isSubscribed { return true }
        if let until = plusGrantedUntil, until > Date() { return true }
        return false
    }

    /// Records Frij+ time earned from invites. Only ever extends — a stale or
    /// missing value from the server can't take away time already granted.
    func applyPlusGrant(until date: Date?) {
        guard let date else { return }
        if let existing = plusGrantedUntil, existing >= date { return }
        plusGrantedUntil = date
        UserDefaults.standard.set(date, forKey: Self.grantKey)
    }
    var purchaseError: String?
    var showPaywall = false

    /// Where the paywall was opened from, sent with the `paywall_view` event so
    /// we can see which moment actually converts. Set via presentPaywall(from:).
    private(set) var paywallSource = "unknown"

    /// Opens the paywall and remembers why. Prefer this over flipping
    /// showPaywall directly so every view is attributed.
    func presentPaywall(from source: String) {
        paywallSource = source
        showPaywall = true
    }

    /// The annual plan's free trial — only when App Store Connect has one
    /// configured AND this Apple ID hasn't used it before. nil means the
    /// paywall shows plain prices, so shipping this before the offer exists
    /// in App Store Connect is harmless.
    private(set) var annualTrial: Product.SubscriptionOffer?

    /// "7-day", "1-month"… for the trial's length, or nil when there's no trial.
    var trialLengthText: String? {
        guard let p = annualTrial?.period else { return nil }
        switch p.unit {
        case .day:   return "\(p.value)-day"
        case .week:  return "\(p.value * 7)-day"
        case .month: return "\(p.value)-month"
        case .year:  return "\(p.value)-year"
        @unknown default: return nil
        }
    }

    // Background listener handle — keeps the Task alive for the app lifetime.
    private var listenerTask: Task<Void, Never>?

    private init() {
        listenerTask = startTransactionListener()
        Task {
            await loadProducts()
            await refreshStatus()
        }
    }

    /// "7 days", "1 month"… for running text, or nil when there's no trial.
    var trialDurationText: String? {
        guard let p = annualTrial?.period else { return nil }
        let days = p.unit == .week ? p.value * 7 : p.value
        switch p.unit {
        case .day, .week: return days == 1 ? "1 day" : "\(days) days"
        case .month: return p.value == 1 ? "1 month" : "\(p.value) months"
        case .year:  return p.value == 1 ? "1 year" : "\(p.value) years"
        @unknown default: return nil
        }
    }

    // MARK: Products

    func loadProducts(force: Bool = false) async {
        guard force || products.isEmpty else { return }
        do {
            let loaded = try await Product.products(for: [Self.monthlyID, Self.annualID])
            // Keep previously-loaded products if a forced refresh returns empty
            // (transient failure) rather than blanking the paywall.
            if !loaded.isEmpty {
                products = loaded.sorted { $0.price < $1.price }
            }
            await refreshTrialEligibility()
        } catch {
            // Network unavailable or product IDs not yet configured — degrade gracefully.
        }
    }

    /// Re-checks whether the annual trial is on offer to this Apple ID. Apple
    /// allows one intro offer per subscription group, ever, so this flips to
    /// nil after the first trial (or any earlier purchase).
    func refreshTrialEligibility() async {
        guard let annual = products.first(where: { $0.id == Self.annualID }),
              let info = annual.subscription,
              let offer = info.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await info.isEligibleForIntroOffer
        else {
            annualTrial = nil
            return
        }
        annualTrial = offer
    }

    // MARK: Subscription status

    /// Re-derives subscription state directly from StoreKit's verified entitlements.
    /// Call on launch, app-foreground, and after any transaction event.
    func refreshStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            // .unverified means the JWS signature failed — never trust it.
            guard case .verified(let tx) = result else { continue }
            guard tx.productType == .autoRenewable else { continue }
            guard [Self.monthlyID, Self.annualID].contains(tx.productID) else { continue }
            // revocationDate is set when Apple refunds or revokes the purchase.
            guard tx.revocationDate == nil else { continue }
            active = true
            break
        }
        isSubscribed = active
    }

    // MARK: Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        // Captured before buying: eligibility is gone once the trial starts.
        let startsTrial = product.id == Self.annualID && annualTrial != nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let tx) = verification else {
                    purchaseError = "Purchase couldn't be verified. Please try again."
                    return
                }
                await tx.finish()
                await refreshStatus()
                if isSubscribed {
                    showPaywall = false
                    // Server can't see StoreKit purchases — report it so the
                    // subscribe count is real.
                    let plan = product.id == Self.annualID ? "annual" : "monthly"
                    FrijAPI.reportEvent("subscribe", props: ["plan": plan, "trial": startsTrial,
                                                             "source": paywallSource])
                    await refreshTrialEligibility()
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Your purchase is awaiting approval."
            @unknown default:
                break
            }
        } catch {
            // StoreKitError.userCancelled surfaces here on some OS versions.
            if let skErr = error as? StoreKitError, case .userCancelled = skErr { return }
            purchaseError = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshStatus()
            if isSubscribed { showPaywall = false }
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: Transaction listener

    // Handles renewals, refunds, and family-sharing grants that arrive while
    // the app is running — keeps isSubscribed in sync without any polling.
    private func startTransactionListener() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let tx) = result else { continue }
                await tx.finish()
                await self?.refreshStatus()
            }
        }
    }
}
