import Foundation

// Meal hand-off between users with ZERO backend state: the recipe itself is
// encoded into the link (base64url JSON in the URL fragment). A Frij owner
// taps the link → the app opens and the meal lands in their Saved. Anyone
// else lands on a lightweight web card that renders the same payload and
// points at the App Store — even non-users see a real recipe, not a wall.
enum RecipeShareLink {
    static let base = "https://frij-backend.vercel.app/r"
    private static let version = "R1."

    static func url(for recipe: Recipe) -> URL? {
        // Strip the personal "Because you…" — it was about the sender, and
        // it would read as nonsense (or surveillance) to the recipient.
        let clean = Recipe(name: recipe.name, cookTime: recipe.cookTime,
                           uses: recipe.uses, needs: recipe.needs,
                           steps: recipe.steps, reason: nil, origin: recipe.origin)
        guard let data = try? JSONEncoder().encode(clean) else { return nil }
        let b64 = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "\(base)#\(version)\(b64)")
    }

    static func decode(from url: URL) -> Recipe? {
        guard url.path.hasPrefix("/r"),
              let fragment = url.fragment(percentEncoded: false) ?? url.fragment,
              fragment.hasPrefix(version) else { return nil }
        var b64 = String(fragment.dropFirst(version.count))
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let recipe = try? JSONDecoder().decode(Recipe.self, from: data) else { return nil }
        // Arriving by link: keep a real origin (Instagram etc.), otherwise
        // credit the sender.
        return Recipe(name: recipe.name, cookTime: recipe.cookTime,
                      uses: recipe.uses, needs: recipe.needs,
                      steps: recipe.steps, reason: nil,
                      origin: recipe.origin ?? "a friend")
    }
}
