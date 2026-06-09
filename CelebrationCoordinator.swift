import Foundation

@MainActor
@Observable
final class CelebrationCoordinator {
    static let shared = CelebrationCoordinator()
    private init() {}

    var isShowing = false
    var streak = 0

    func show(streak: Int) {
        self.streak = streak
        isShowing = true
    }

    func dismiss() {
        isShowing = false
    }
}
