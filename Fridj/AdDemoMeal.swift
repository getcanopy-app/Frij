import Foundation

// AD DEMO — DEBUG ONLY, never in a Release/App Store build.
//
// For filming a Frij ad: when the pantry is the ad's exact set (chicken +
// rice + tomatoes), a cook returns ONE guaranteed dish — "Grilled Chicken
// with Tomato Rice" — with the hero image already cached on the backend under
// that name, so it loads instantly on camera. No live-generation gamble
// between takes; the same beautiful plate appears every time.
//
// The whole file is wrapped in #if DEBUG, and the hook in ScanSession is too,
// so this cannot ship. To retire it after the shoot, delete this file and the
// #if DEBUG block in ScanSession.cook.
#if DEBUG
enum AdDemoMeal {
    // Fires only when all three ad ingredients are present — specific enough
    // that ordinary debug testing never trips it by accident.
    static func matches(_ ingredients: [String]) -> Bool {
        let hay = ingredients.map { $0.lowercased() }
        func has(_ words: [String]) -> Bool {
            hay.contains { name in words.contains { name.contains($0) } }
        }
        return has(["chicken"]) && has(["rice"]) && has(["tomato", "tomatoes"])
    }

    // Name MUST match the backend's cached image key exactly, so MealImageView
    // pulls the generated hero instead of asking for a new one.
    static let recipe = Recipe(
        name: "Grilled Chicken with Tomato Rice",
        cookTime: "30 min",
        // Everything's a "use" and nothing's a "need" so the card reads fully
        // stocked — the ad's whole point is "cook what you already have."
        uses: ["chicken", "rice", "tomatoes"],
        needs: [],
        steps: [
            "Season the chicken with salt, pepper and a little oil; let it sit while the grill heats.",
            "Grill the chicken over medium-high heat, 5–6 minutes a side, until charred and cooked through. Rest it.",
            "Sauté diced onion and garlic in oil until soft, then stir in the rice to toast for a minute.",
            "Add chopped tomatoes and water; simmer covered until the rice is tender and stained deep red.",
            "Slice the chicken, lay it over the tomato rice, and finish with fresh parsley."
        ],
        reason: nil,
        origin: nil
    )
}
#endif
