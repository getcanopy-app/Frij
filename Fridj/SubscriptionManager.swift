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
    var purchaseError: String?
    var showPaywall = false

    // Background listener handle — keeps the Task alive for the app lifetime.
    private var listenerTask: Task<Void, Never>?

    private init() {
        listenerTask = startTransactionListener()
        Task {
            await loadProducts()
            await refreshStatus()
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
        } catch {
            // Network unavailable or product IDs not yet configured — degrade gracefully.
        }
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
                    FrijAPI.reportEvent("subscribe", props: ["plan": plan])
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
