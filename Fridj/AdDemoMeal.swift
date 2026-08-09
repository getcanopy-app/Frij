import Foundation

// AD / DEMO MEALS — DEBUG ONLY, never in a Release/App Store build.
//
// For filming and demos: when the pantry matches a demo's exact ingredient
// set, a cook returns that ONE guaranteed dish — its hero image is already
// generated and cached on the backend under the same name, so it loads
// instantly and identically every take. No live-generation gamble on camera.
//
// The whole file is #if DEBUG, and so is the hook in ScanSession.cook, so none
// of this can ship. To retire it, delete this file and the DEBUG block in
// ScanSession.cook. To add another demo meal, append to `all`.
#if DEBUG
struct DemoMeal {
    let triggers: [[String]]   // each inner group is an OR; all groups must hit
    let recipe: Recipe
}

enum AdDemoMeal {
    // Returns the demo recipe whose triggers the pantry satisfies, or nil.
    static func match(_ ingredients: [String]) -> Recipe? {
        let hay = ingredients.map { $0.lowercased() }
        func has(_ words: [String]) -> Bool {
            hay.contains { name in words.contains { name.contains($0) } }
        }
        return all.first { meal in meal.triggers.allSatisfy { has($0) } }?.recipe
    }

    // Names MUST match the backend's cached image keys exactly, so MealImageView
    // pulls the generated hero instead of asking for a new one. ORDER MATTERS:
    // match() returns the first hit, so list the rarest/most-deliberate trigger
    // first. Avocado before tomato means "added avocado -> the avocado bowl"
    // even when the pantry also happens to hold a tomato.
    static let all: [DemoMeal] = [
        // Chicken + rice + avocado — plated to match the real ad dish.
        DemoMeal(
            triggers: [["chicken"], ["rice"], ["avocado"]],
            recipe: Recipe(
                name: "Grilled Chicken with Rice Pilaf and Avocado",
                cookTime: "30 min",
                uses: ["chicken", "rice", "avocado"],
                needs: [],
                steps: [
                    "Season the chicken generously with salt, pepper and a little oil; let it sit while the grill or pan heats.",
                    "Grill over medium-high heat, 5–6 minutes a side, until deeply charred and cooked through. Rest it.",
                    "Toast the rice in a little butter, then simmer in broth with a handful of diced veg until fluffy — a quick pilaf.",
                    "Halve, pit and thinly slice the avocado, then fan the slices out.",
                    "Plate the rice pilaf, lay the grilled chicken alongside, add the avocado, and finish with fresh herbs."
                ]
            )
        ),
        // Ad hero: grilled chicken over tomato rice (no avocado in the pantry).
        DemoMeal(
            triggers: [["chicken"], ["rice"], ["tomato", "tomatoes"]],
            recipe: Recipe(
                name: "Grilled Chicken with Tomato Rice",
                cookTime: "30 min",
                uses: ["chicken", "rice", "tomatoes"],
                needs: [],
                steps: [
                    "Season the chicken with salt, pepper and a little oil; let it sit while the grill heats.",
                    "Grill the chicken over medium-high heat, 5–6 minutes a side, until charred and cooked through. Rest it.",
                    "Sauté diced onion and garlic in oil until soft, then stir in the rice to toast for a minute.",
                    "Add chopped tomatoes and water; simmer covered until the rice is tender and stained deep red.",
                    "Slice the chicken, lay it over the tomato rice, and finish with fresh parsley."
                ]
            )
        ),
    ]
}
#endif
