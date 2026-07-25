import SwiftUI

// The 8 quiz dishes. Every one is in the backend's pre-generated image catalog
// so the grid loads from cache, and each carries a tiny hint that rides into
// the taste brief — the LLM reads most of the signal from the dish name itself;
// the hint just sharpens it. Together the 8 span the axes that matter: quick vs
// project, meat vs plant, comfort vs fresh, familiar vs adventurous.
enum TasteQuiz {
    static let items: [(name: String, hint: String)] = [
        ("Spaghetti Carbonara", "comfort pasta"),
        ("Chicken Stir Fry",    "quick and savory"),
        ("Shakshuka",           "eggs, a bit adventurous"),
        ("Beef Tacos",          "bold, handheld"),
        ("Pan-Seared Salmon",   "light and fresh"),
        ("Veggie Stir Fry",     "plant-forward"),
        ("Ramen",               "cozy noodles"),
        ("Beef Stew",           "slow, hearty cooking"),
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
