import Foundation
import Observation

// Behavioral taste signals beyond saves — the watch→learn half of
// personalization. Two signals, both one tap:
//   • cooked   — dishes the user actually MADE ("I cooked this"). The strongest
//                positive signal there is: you cook what you truly want, not
//                just what caught your eye.
//   • disliked — dishes the user waved off ("Not for me"). A soft negative used
//                to show fewer like them.
// Persisted locally like FavoritesStore; a sync target when accounts arrive.
@MainActor @Observable
final class TasteSignalsStore {
    static let shared = TasteSignalsStore()

    private(set) var cooked: [Recipe] = []
    private(set) var disliked: [String] = []
    // Onboarding taste-quiz picks — the day-one seed. Fades out of the brief
    // once real saves/cooks accumulate (TasteProfile handles the fade).
    private(set) var quizPicks: [String] = []

    private let cookedKey = "frij.taste.cooked.v1"
    private let dislikedKey = "frij.taste.disliked.v1"
    private let quizKey = "frij.taste.quiz.v1"
    private let defaults: UserDefaults

    // Recent history is what matters; old signals get dropped so taste can drift.
    private let cookedCap = 30
    private let dislikedCap = 40

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cooked = Self.loadRecipes(from: defaults, key: cookedKey)
        self.disliked = defaults.stringArray(forKey: dislikedKey) ?? []
        self.quizPicks = defaults.stringArray(forKey: quizKey) ?? []
    }

    func setQuizPicks(_ names: [String]) {
        quizPicks = names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        defaults.set(quizPicks, forKey: quizKey)
    }

    func logCooked(_ recipe: Recipe) {
        cooked.removeAll { $0.id == recipe.id }
        cooked.insert(recipe, at: 0)   // newest first
        if cooked.count > cookedCap { cooked = Array(cooked.prefix(cookedCap)) }
        saveCooked()
    }

    /// Reverses a cook log — used when the user taps Undo right after.
    func undoCooked(_ recipe: Recipe) {
        cooked.removeAll { $0.id == recipe.id }
        saveCooked()
    }

    func dislike(_ recipe: Recipe) {
        let name = recipe.name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        disliked.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        disliked.insert(name, at: 0)
        if disliked.count > dislikedCap { disliked = Array(disliked.prefix(dislikedCap)) }
        defaults.set(disliked, forKey: dislikedKey)
    }

    private func saveCooked() {
        if let data = try? JSONEncoder().encode(cooked) {
            defaults.set(data, forKey: cookedKey)
        }
    }

    private static func loadRecipes(from defaults: UserDefaults, key: String) -> [Recipe] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Recipe].self, from: data)) ?? []
    }
}
