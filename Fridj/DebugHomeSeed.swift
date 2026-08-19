#if DEBUG
import Foundation

/// DEBUG-ONLY — compiled entirely out of App Store (Release) builds.
///
/// Stocks the Home "recent ideas" row with a fixed set of appetizing meals plus
/// their pre-generated photos, so an ad/demo can be screen-recorded from a plain
/// Xcode build of the real app (⌘R) without the separate Frij-ad target. It
/// records the meals to the top of history (so Home shows them first) and stocks
/// the pantry with their ingredients (so the cards read "in stock").
///
/// To change the ad meals, edit `meals` below. To turn it off, delete the
/// `#if DEBUG` call in FridjApp — or this whole file. It NEVER affects the
/// shipped app.
enum DebugHomeSeed {
    private static let base =
        "https://geztnivcccmgjybxmdin.supabase.co/storage/v1/object/public/Meal-images/"

    private struct Meal {
        let name: String, cookTime: String, uses: [String], needs: [String], slug: String, steps: [String]
    }

    private static let meals: [Meal] = [
        Meal(name: "Grilled Chicken with Tomato Rice", cookTime: "30 min",
             uses: ["chicken breast", "rice", "tomato"], needs: ["garlic", "onion"],
             slug: "grilled-chicken-with-tomato-rice",
             steps: ["Season the chicken and grill 5–6 minutes a side until cooked through; rest.",
                     "Sauté onion and garlic, then toast the rice for a minute.",
                     "Add chopped tomatoes and water, cover, and simmer until fluffy.",
                     "Slice the chicken and serve over the tomato rice."]),
        Meal(name: "Creamy Garlic Pasta with Steak", cookTime: "25 min",
             uses: ["steak", "pasta", "garlic"], needs: ["cream", "parmesan"],
             slug: "creamy-garlic-pasta-with-steak",
             steps: ["Sear the steak to your liking, rest, and slice thin.",
                     "Boil the pasta until al dente, saving a splash of pasta water.",
                     "Soften garlic in butter, add cream and parmesan for a silky sauce.",
                     "Toss the pasta in the sauce and top with the sliced steak."]),
        Meal(name: "Buffalo Chicken Fettuccine", cookTime: "25 min",
             uses: ["chicken", "fettuccine"], needs: ["buffalo sauce", "cream"],
             slug: "buffalo-chicken-fettuccine",
             steps: ["Cook the fettuccine until al dente.",
                     "Sear bite-size chicken until golden and cooked through.",
                     "Stir buffalo sauce with cream and butter into a glossy sauce.",
                     "Fold in the pasta and chicken; finish with green onion."]),
        Meal(name: "Chimichurri Steak over Rice", cookTime: "30 min",
             uses: ["steak", "rice"], needs: ["parsley", "garlic"],
             slug: "chimichurri-steak-over-rice",
             steps: ["Blend parsley, garlic, olive oil, vinegar and chili into a chimichurri.",
                     "Cook the rice until fluffy.",
                     "Sear the steak to medium-rare, rest, and slice against the grain.",
                     "Pile the steak over the rice and spoon the chimichurri on top."]),
        Meal(name: "Lemon Garlic Chicken", cookTime: "25 min",
             uses: ["chicken", "lemon", "garlic"], needs: ["butter"],
             slug: "lemon-garlic-chicken",
             steps: ["Season the chicken and sear until golden on both sides.",
                     "Add butter, garlic and a squeeze of lemon to the pan.",
                     "Spoon the sauce over and simmer until cooked through.",
                     "Finish with lemon zest and parsley."]),
    ]

    @MainActor
    static func apply() {
        for m in meals {
            if let url = URL(string: base + m.slug + ".png") {
                MealImageCache.shared.set(url, for: m.name)
            }
            for ingredient in m.uses + m.needs {
                PantryStore.shared.addLocal(name: ingredient, source: .scanned)
            }
        }
        // Record to the TOP of history so Home's "recent ideas" shows these first.
        let recipes = meals.map {
            Recipe(name: $0.name, cookTime: $0.cookTime, uses: $0.uses,
                   needs: $0.needs, steps: $0.steps, mode: "dinner")
        }
        RecipeHistoryStore.shared.record(recipes)
    }
}
#endif
