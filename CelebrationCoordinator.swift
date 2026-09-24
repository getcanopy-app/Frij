import Foundation

@MainActor
@Observable
final class CelebrationCoordinator {
    static let shared = CelebrationCoordinator()
    private init() {}

    var isShowing = false
    var streak = 0

    /// True while the recipe sheet is on screen and hosting the celebration
    /// itself. Two copies of an overlay (one in the sheet, one on the base
    /// window) fight over touches — on iOS 17 badly enough that neither the
    /// celebration nor the buttons under it respond. Exactly one host at a
    /// time, and this says which.
    var hostedBySheet = false

    func show(streak: Int) {
        self.streak = streak
        isShowing = true
    }

    func dismiss() {
        isShowing = false
    }
}
