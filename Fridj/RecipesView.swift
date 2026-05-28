import SwiftUI

// Replaces the "Coming soon" RecipesView placeholder.
// Shows the 3 dinners the backend returned. Accepts recipes so ScanView
// can present it; defaults to empty for the standalone tab/preview.

struct RecipesView: View {
    var recipes: [Recipe] = []
    @State private var expanded: String?

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            if recipes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: FridjSpacing.md) {
                        Text("Tonight's options")
                            .font(FridjFont.style(.title, weight: .bold))
                            .foregroundColor(.fridjText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 60)

                        ForEach(recipes) { recipe in
                            card(recipe)
                        }
                    }
                    .padding(FridjSpacing.lg)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: FridjSpacing.md) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.fridjOrange)
            Text("No recipes yet")
                .font(FridjFont.style(.title2, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Scan your fridge to get dinner ideas.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.4))
        }
    }

    private func card(_ recipe: Recipe) -> some View {
        let isOpen = expanded == recipe.id
        return VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack(alignment: .top) {
                Text(recipe.name)
                    .font(FridjFont.size(18, weight: .bold))
                    .foregroundColor(.fridjText)
                Spacer()
                Text(recipe.cookTime)
                    .font(FridjFont.size(12, weight: .bold))
                    .foregroundColor(.fridjGreen)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.fridjMint.opacity(0.5), in: Capsule())
            }

            Text("uses " + recipe.uses.joined(separator: ", "))
                .font(FridjFont.size(13))
                .foregroundColor(.fridjText.opacity(0.5))

            if !recipe.needs.isEmpty {
                Text("you'll need: " + recipe.needs.joined(separator: ", "))
                    .font(FridjFont.size(13, weight: .medium))
                    .foregroundColor(.fridjOrange)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded = isOpen ? nil : recipe.id
                }
            } label: {
                Text(isOpen ? "hide steps ↑" : "make this ↓")
                    .font(FridjFont.size(14, weight: .bold))
                    .foregroundColor(.fridjOrange)
            }

            if isOpen {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1)")
                                .font(FridjFont.size(12, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.fridjGreen, in: Circle())
                            Text(step)
                                .font(FridjFont.size(14))
                                .foregroundColor(.fridjText.opacity(0.8))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(FridjSpacing.md)
        .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous))
    }
}

#Preview {
    RecipesView(recipes: [
        Recipe(name: "Cheddar Quesadillas", cookTime: "15 min",
               uses: ["cheddar cheese", "sour cream"], needs: ["tortillas"],
               steps: ["Heat a skillet.", "Add cheese to a tortilla.", "Fold and cook until golden.", "Serve with sour cream."])
    ])
}
