import SwiftUI

struct RecipesView: View {
    var recipes: [Recipe] = []
    @State private var selected: Recipe?

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
                                .onTapGesture { selected = recipe }
                        }
                    }
                    .padding(FridjSpacing.lg)
                    .padding(.bottom, FridjSpacing.lg)
                }
            }
        }
        .sheet(item: $selected) { recipe in
            RecipeDetailView(recipe: recipe)
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
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
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

            HStack {
                Spacer()
                Label("View recipe", systemImage: "chevron.right")
                    .font(FridjFont.size(13, weight: .bold))
                    .foregroundColor(.fridjOrange)
            }
            .padding(.top, 2)
        }
        .padding(FridjSpacing.md)
        .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous))
    }
}

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.fridjBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FridjSpacing.xl) {

                    VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                        Text(recipe.name)
                            .font(FridjFont.style(.largeTitle, weight: .bold))
                            .foregroundColor(.fridjText)

                        Text(recipe.cookTime)
                            .font(FridjFont.size(14, weight: .bold))
                            .foregroundColor(.fridjGreen)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.fridjMint.opacity(0.5), in: Capsule())
                    }
                    .padding(.top, 60)

                    section(title: "What you're using") {
                        FlowTags(items: recipe.uses, color: .fridjGreen)
                    }

                    if !recipe.needs.isEmpty {
                        section(title: "You'll also need") {
                            FlowTags(items: recipe.needs, color: .fridjOrange)
                        }
                    }

                    section(title: "How to make it") {
                        VStack(alignment: .leading, spacing: FridjSpacing.md) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: FridjSpacing.md) {
                                    Text("\(idx + 1)")
                                        .font(FridjFont.size(13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Color.fridjGreen, in: Circle())

                                    Text(step)
                                        .font(FridjFont.size(15))
                                        .foregroundColor(.fridjText.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(FridjSpacing.lg)
                .padding(.bottom, FridjSpacing.xl)
            }

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.fridjText.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
            }
            .padding(FridjSpacing.lg)
            .padding(.top, 8)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            Text(title)
                .font(FridjFont.size(13, weight: .bold))
                .foregroundColor(.fridjText.opacity(0.4))
                .textCase(.uppercase)
                .kerning(0.8)
            content()
        }
        .padding(FridjSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
    }
}

struct FlowTags: View {
    let items: [String]
    let color: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(FridjFont.size(13, weight: .medium))
                    .foregroundColor(color)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(color.opacity(0.12), in: Capsule())
            }
        }
    }
}

#Preview {
    RecipesView(recipes: [
        Recipe(name: "Cheddar Quesadillas", cookTime: "15 min",
               uses: ["cheddar cheese", "sour cream"], needs: ["tortillas"],
               steps: ["Heat a skillet over medium heat.", "Add cheese to a tortilla.", "Fold and cook until golden.", "Serve with sour cream."])
    ])
}
