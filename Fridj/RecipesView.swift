import SwiftUI

// 3 dinners from the backend. Each card expands to show steps and the
// "I cooked this" button that subtracts the recipe's uses from the pantry.

struct RecipesView: View {
    var recipes: [Recipe] = []
    @State private var expanded: String?
    @State private var store = PantryStore.shared

    // After cooking, we hold the just-removed items briefly so the user can undo.
    @State private var lastRemoved: [String] = []
    @State private var showUndoFor: String?  // recipe id while undo banner is showing

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

            // Undo banner — slides up from the bottom when something was just removed.
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

                // I cooked this button — the satisfying tap.
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
        .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous))
    }

    private func markCooked(_ recipe: Recipe) {
        // Subtract the recipe's uses from the pantry. Keep a snapshot so the
        // undo banner can put them back if the user tapped by accident.
        let removed = recipe.uses.filter { store.contains($0) }
        guard !removed.isEmpty else { return }
        for name in removed { store.remove(name: name) }
        lastRemoved = removed
        showUndoFor = recipe.id

        // Auto-hide the undo banner after 5 seconds.
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
