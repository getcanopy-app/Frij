import StoreKit
import UIKit

/// Asks for an App Store rating at a moment the user just succeeded: their
/// third cooked meal, once per app version. Ratings drive App Store search
/// rank, so this is a growth lever, not decoration.
///
/// Stays off the invite nudge's beats (2nd cook, then every 5th) so the two
/// never compete. iOS itself also caps the system prompt at 3 per year and may
/// silently skip it, so this is a request, never a guarantee.
@MainActor
enum ReviewPrompt {
    private static let cooksKey = "frij.review.cooks"
    private static let askedVersionKey = "frij.review.askedVersion"

    static func recordCook() {
        let defaults = UserDefaults.standard
        let n = defaults.integer(forKey: cooksKey) + 1
        defaults.set(n, forKey: cooksKey)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard n >= 3, n % 5 != 0, defaults.string(forKey: askedVersionKey) != version else { return }
        defaults.set(version, forKey: askedVersionKey)

        // Let the cooking celebration land first, same beat as the invite nudge.
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
            else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
