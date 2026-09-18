import Foundation
import HealthKit

/// Optional: write each cooked meal's macros to Apple Health, so calorie
/// trackers that read from Health (Cronometer, Lose It!, MacroFactor, …) pick
/// it up without the user typing anything.
///
/// Write-only on purpose. Frij never reads Health data — that keeps the
/// permission sheet short, the privacy story simple, and nothing to explain in
/// App Review beyond "we save the meal you just cooked".
///
/// A Frij+ perk, off until the user turns it on in Profile. Like invites, this must never be
/// able to break cooking, so every failure is swallowed.
@MainActor @Observable
final class HealthLog {
    static let shared = HealthLog()

    private let store = HKHealthStore()
    private let enabledKey = "frij.health.enabled"

    /// The user's choice. Distinct from iOS permission: someone can turn this
    /// on and then deny in the sheet, or revoke later in Settings.
    private(set) var isEnabled: Bool

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
    }

    private static let types: [(HKQuantityTypeIdentifier, HKUnit)] = [
        (.dietaryEnergyConsumed, .kilocalorie()),
        (.dietaryProtein, .gram()),
        (.dietaryCarbohydrates, .gram()),
        (.dietaryFiber, .gram()),
        (.dietaryFatTotal, .gram()),
    ]

    // Only the nutrients. Asking to share HKCorrelationType(.food) itself is
    // an NSInvalidArgumentException crash — a food correlation is allowed
    // whenever its member types are.
    private var shareTypes: Set<HKSampleType> {
        Set(Self.types.map { HKQuantityType($0.0) })
    }

    /// Turning on shows the iOS permission sheet (only the first time — after
    /// that iOS remembers, and changes happen in the Health app).
    func setEnabled(_ on: Bool) async {
        guard on else {
            isEnabled = false
            UserDefaults.standard.set(false, forKey: enabledKey)
            return
        }
        guard Self.isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: [])
        } catch {
            return
        }
        isEnabled = true
        UserDefaults.standard.set(true, forKey: enabledKey)
    }

    /// True when the user turned it on but iOS says we can't write — i.e. they
    /// tapped "Don't Allow" or revoked it. Profile uses this to say so instead
    /// of showing a toggle that silently does nothing.
    var isDenied: Bool {
        isEnabled && store.authorizationStatus(for: HKQuantityType(.dietaryEnergyConsumed)) != .sharingAuthorized
    }

    /// Save one serving of a cooked recipe as a single food entry.
    func log(_ recipe: Recipe) {
        // Frij+ only. Checked here too, not just in Profile: someone who turned
        // it on and then let the subscription lapse stops syncing.
        guard isEnabled, SubscriptionManager.shared.hasPlus,
              Self.isAvailable, let n = recipe.nutrition else { return }

        let now = Date()
        let values: [HKQuantityTypeIdentifier: Int?] = [
            .dietaryEnergyConsumed: n.calories,
            .dietaryProtein: n.protein,
            .dietaryCarbohydrates: n.carbs,
            .dietaryFiber: n.fiber,
            .dietaryFatTotal: n.fat,
        ]
        // The dish name, so Health shows "Garlic butter salmon", not "Food".
        let meta: [String: Any] = [HKMetadataKeyFoodType: recipe.name]

        var samples = Set<HKSample>()
        for (id, unit) in Self.types {
            // Skip missing and zero values: "0 g protein" would be a claim,
            // not an absence of one.
            guard let v = values[id] ?? nil, v > 0,
                  store.authorizationStatus(for: HKQuantityType(id)) == .sharingAuthorized
            else { continue }
            samples.insert(HKQuantitySample(type: HKQuantityType(id),
                                            quantity: HKQuantity(unit: unit, doubleValue: Double(v)),
                                            start: now, end: now, metadata: meta))
        }
        guard !samples.isEmpty else { return }

        // A food correlation groups the macros into one meal in Health.
        let meal = HKCorrelation(type: HKCorrelationType(.food), start: now, end: now,
                                 objects: samples, metadata: meta)
        store.save(meal) { _, error in
            if let error { print("HealthLog save failed:", error) }
        }
    }
}
