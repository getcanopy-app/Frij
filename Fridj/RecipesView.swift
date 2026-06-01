import SwiftUI

struct RecipesView: View {
    var recipes: [Recipe] = []
    @State private var expanded: String?
    @State private var store = PantryStore.shared
    @State private var favorites = FavoritesStore.shared

    @State private var lastRemoved: [String] = []
    @State private var showUndoFor: String?

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

            if let recipeId = showUndoFor, !lastRemoved.isEmpty {
                VStack {
                    Spacer()
                    HStack {
                        Text("Removed \(lastRemoved.count) \(lastRemoved.count == 1 ? "item" : "items") from pantry")
                            .font(FridjFont.size(14, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Button("Undo") {
                            for name in lastRemoved {
                                store.addLocal(name: name, source: .scanned)
                            }
                            lastRemoved = []
                            showUndoFor = nil
                        }
                        .font(FridjFont.size(14, weight: .bold))
                        .foregroundColor(.fridjOrange)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 14)
                    .background(Color.fridjText, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                    .padding(.horizontal, FridjSpacing.lg)
                    .padding(.bottom, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(recipeId)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showUndoFor)
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
        let isFav = favorites.isFavorite(recipe)
        return VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack(alignment: .top, spacing: 10) {
                Text(recipe.name)
                    .font(FridjFont.size(18, weight: .bold))
                    .foregroundColor(.fridjText)

                Spacer()

                // Favorite heart — sits next to the cook time
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                        _ = favorites.toggle(recipe)
                    }
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isFav ? .fridjCoral : .fridjText.opacity(0.35))
                        .scaleEffect(isFav ? 1.0 : 1.0)
                }
                .buttonStyle(.plain)

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

                Button {
                    markCooked(recipe)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text("I cooked this")
                            .font(FridjFont.size(16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.fridjGreen,
                                in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                }
                .padding(.top, 8)
            }
        }
        .padding(FridjSpacing.md)
        .background(RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous).fill(Color(white: 1)))
    }

    private func markCooked(_ recipe: Recipe) {
        let removed = recipe.uses.filter { store.contains($0) }
        guard !removed.isEmpty else { return }
        for name in removed { store.remove(name: name) }
        lastRemoved = removed
        showUndoFor = recipe.id

        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                if showUndoFor == recipe.id {
                    showUndoFor = nil
                    lastRemoved = []
                }
            }
        }
    }
}

#Preview {
    RecipesView(recipes: [
        Recipe(name: "Cheddar Quesadillas", cookTime: "15 min",
               uses: ["cheddar cheese", "sour cream"], needs: ["tortillas"],
               steps: ["Heat a skillet.", "Add cheese to a tortilla.", "Fold and cook until golden.", "Serve with sour cream."])
    ])
}
