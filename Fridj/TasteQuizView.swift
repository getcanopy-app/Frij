import SwiftUI

// The 8 quiz dishes. Every one is in the backend's pre-generated image catalog
// so the grid loads from cache, and each carries a tiny hint that rides into
// the taste brief — the LLM reads most of the signal from the dish name itself;
// the hint just sharpens it. Together the 8 span the axes that matter: quick vs
// project, meat vs plant, comfort vs fresh, familiar vs adventurous.
enum TasteQuiz {
    static let items: [(name: String, hint: String, time: String)] = [
        ("Spaghetti Carbonara", "comfort pasta",           "25 min"),
        ("Chicken Stir Fry",    "quick and savory",        "20 min"),
        ("Shakshuka",           "eggs, a bit adventurous", "25 min"),
        ("Beef Tacos",          "bold, handheld",          "20 min"),
        ("Pan-Seared Salmon",   "light and fresh",         "20 min"),
        ("Veggie Stir Fry",     "plant-forward",           "15 min"),
        ("Ramen",               "cozy noodles",            "30 min"),
        ("Beef Stew",           "slow, hearty cooking",    "1 hr 30 min"),
    ]

    static func cookTime(for name: String) -> String {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.time ?? ""
    }

    /// Full recipes for the quiz dishes, so a teaser card on Home opens the
    /// same detail sheet as any other meal instead of dead-ending into a scan.
    /// `uses` stays empty (nothing here is from the user's pantry — that's the
    /// point); the ingredients live in `needs` as the shopping list.
    static func recipe(for name: String) -> Recipe {
        let steps = recipeContent[name.lowercased()]
        return Recipe(name: name,
                      cookTime: cookTime(for: name),
                      uses: [],
                      needs: steps?.needs ?? [],
                      steps: steps?.steps ?? [])
    }

    private static let recipeContent: [String: (needs: [String], steps: [String])] = [
        "spaghetti carbonara": (
            ["spaghetti", "eggs", "parmesan", "bacon or pancetta"],
            ["Boil the spaghetti in well-salted water until al dente.",
             "Crisp chopped bacon in a pan; keep the fat.",
             "Whisk eggs with grated parmesan and lots of black pepper.",
             "Off the heat, toss hot pasta with the bacon, then the egg mix, loosening with pasta water until silky.",
             "Serve immediately with more parmesan and pepper."]),
        "chicken stir fry": (
            ["chicken breast", "soy sauce", "garlic", "mixed vegetables", "rice"],
            ["Cook rice and slice chicken into thin strips.",
             "Sear the chicken hard in a hot pan with oil; set aside.",
             "Stir-fry the vegetables with garlic until crisp-tender.",
             "Return the chicken, splash in soy sauce, toss for a minute.",
             "Serve over the rice."]),
        "shakshuka": (
            ["eggs", "crushed tomatoes", "onion", "bell pepper", "cumin", "paprika"],
            ["Soften diced onion and bell pepper in olive oil.",
             "Add cumin and paprika, then the crushed tomatoes; simmer 10 minutes.",
             "Make wells in the sauce and crack in the eggs.",
             "Cover and cook until the whites set but yolks stay soft.",
             "Serve straight from the pan with bread."]),
        "beef tacos": (
            ["ground beef", "tortillas", "taco seasoning", "onion", "cheese"],
            ["Brown the beef with diced onion, draining excess fat.",
             "Stir in taco seasoning with a splash of water; simmer 5 minutes.",
             "Warm the tortillas in a dry pan.",
             "Fill with beef, cheese, and whatever toppings you like.",
             "Serve with lime if you have it."]),
        "pan-seared salmon": (
            ["salmon fillets", "butter", "lemon", "garlic"],
            ["Pat the salmon dry and season with salt and pepper.",
             "Sear skin-side down in a hot pan until the skin crisps, ~4 minutes.",
             "Flip, add butter and garlic, and baste for 2 more minutes.",
             "Finish with a squeeze of lemon.",
             "Rest a minute and serve with any side you like."]),
        "veggie stir fry": (
            ["mixed vegetables", "soy sauce", "ginger", "garlic", "rice"],
            ["Cook the rice first.",
             "Get a pan screaming hot with a little oil.",
             "Stir-fry the hardest vegetables first, softest last, with garlic and ginger.",
             "Splash in soy sauce and toss until glossy.",
             "Serve over rice."]),
        "ramen": (
            ["ramen noodles", "chicken broth", "soy sauce", "eggs", "scallions"],
            ["Simmer the broth with soy sauce and a little garlic.",
             "Soft-boil the eggs (6½ minutes), then peel and halve.",
             "Cook the noodles separately and drain.",
             "Assemble: noodles, hot broth, eggs, sliced scallions.",
             "Add chili oil or butter if you're feeling it."]),
        "beef stew": (
            ["beef chuck", "potatoes", "carrots", "onion", "beef broth", "tomato paste"],
            ["Brown the beef in batches in a heavy pot; set aside.",
             "Soften onion, then stir in tomato paste.",
             "Return the beef with broth; simmer covered for 1 hour.",
             "Add chunked potatoes and carrots; simmer 30 more minutes until tender.",
             "Season, rest 10 minutes, serve."]),
    ]

    static func hint(for name: String) -> String? {
        items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.hint
    }

    /// Warm all 8 tile photos — resolve each URL into MealImageCache and pull
    /// the bytes into URLCache — so the grid renders instantly when the user
    /// reaches it. Called when onboarding STARTS: the ~10s spent reading the
    /// intro pages hides the whole load.
    static func prefetchImages() async {
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask { @MainActor in
                    let url: URL?
                    if let cached = MealImageCache.shared.url(for: item.name) {
                        url = cached
                    } else if let resolved = try? await FrijAPI.mealImage(dish: item.name) {
                        MealImageCache.shared.set(resolved, for: item.name)
                        url = resolved
                    } else {
                        url = nil
                    }
                    // Pull bytes so AsyncImage serves from URLCache, not the network.
                    if let url { _ = try? await URLSession.shared.data(from: url) }
                }
            }
        }
    }
}

// One-screen taste quiz shown at the end of onboarding: tap what looks good,
// or skip in half a second. Picks seed the taste profile so the very first
// "Get 3 dinners" already feels personal — and the seed fades out once real
// saves/cooks accumulate (see TasteProfile).
struct TasteQuizView: View {
    var onDone: () -> Void

    @State private var picked: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Skip is a first-class exit, not fine print — someone standing at
            // an open fridge at 6pm gets past this in one tap.
            HStack {
                Spacer()
                Button("Skip") { onDone() }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.4))
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)

            VStack(spacing: 8) {
                Text("What looks good?")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
                Text("Tap a few — Frij learns your taste from here.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.5))
            }
            .padding(.top, 12)
            .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                          spacing: 12) {
                    ForEach(TasteQuiz.items, id: \.name) { item in
                        tile(item.name)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            Button {
                TasteSignalsStore.shared.setQuizPicks(Array(picked))
                onDone()
            } label: {
                Text(picked.isEmpty ? "Maybe later" : "Looks good →")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.82),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.horizontal, 28)
            .padding(.top, 8)
            .padding(.bottom, 52)
        }
        .sensoryFeedback(.selection, trigger: picked)
    }

    private func tile(_ name: String) -> some View {
        let isPicked = picked.contains(name)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isPicked { picked.remove(name) } else { picked.insert(name) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                MealImageView(dish: name, cornerRadius: 14)
                    .frame(height: 104)
                    .frame(maxWidth: .infinity)
                    // Clip AFTER the frame — scaledToFill reports oversized
                    // bounds and would bleed past the tile otherwise.
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isPicked ? Color.fridjOrange : .clear, lineWidth: 3)
                    )
                    .overlay(alignment: .topTrailing) {
                        if isPicked {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white, Color.fridjOrange)
                                .padding(7)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                Text(name)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.black.opacity(isPicked ? 0.85 : 0.6))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TasteQuizView(onDone: {})
}
