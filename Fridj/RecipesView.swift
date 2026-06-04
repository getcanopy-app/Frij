import SwiftUI

struct RecipesView: View {
    var recipes: [Recipe] = []
    @State private var expanded: String?
    @State private var store = PantryStore.shared
    @State private var favorites = FavoritesStore.shared

    @State private var lastRemoved: [String] = []
    @State private var showUndoFor: String?

    // Used by the empty state's "scan now" button.
    var onJumpToScan: (() -> Void)? = nil

    private var hasSaved: Bool { !favorites.recipes.isEmpty }
    private var hasFresh: Bool { !recipes.isEmpty }
    private var isCompletelyEmpty: Bool { !hasSaved && !hasFresh }

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            if isCompletelyEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: FridjSpacing.lg) {
                        if hasSaved {
                            savedSection
                        }
                        if hasFresh {
                            tonightSection
                        }
                    }
                    .padding(FridjSpacing.lg)
                    .padding(.top, 60)
                    .padding(.bottom, 120)
                }
            }

            if let recipeId = showUndoFor, !lastRemoved.isEmpty {
                undoBanner(recipeId: recipeId)
            }
        }
    }

    // MARK: Saved

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("Saved")
                    .font(FridjFont.style(.title, weight: .bold))
                    .foregroundColor(.fridjText)
                Spacer()
                Text("\(favorites.recipes.count)")
                    .font(FridjFont.size(14, weight: .bold))
                    .foregroundColor(.fridjText.opacity(0.4))
            }
            Text("Your hearted meals, ready to cook again.")
                .font(FridjFont.size(13))
                .foregroundColor(.fridjText.opacity(0.5))

            ForEach(favorites.recipes) { recipe in
                card(recipe)
            }
        }
    }

    // MARK: Tonight

    private var tonightSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            Text(hasSaved ? "Tonight's options" : "Tonight's options")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)
                .padding(.top, hasSaved ? FridjSpacing.md : 0)

            ForEach(recipes) { recipe in
                card(recipe)
            }
        }
    }

    // MARK: Empty

    private var emptyState: some View {
        VStack(spacing: FridjSpacing.md) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.fridjOrange.opacity(0.7))

            Text("No recipes yet")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)

            Text("Scan your kitchen to get tonight's dinner ideas.\nYour saved favorites will show up here too.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let onJumpToScan {
                Button {
                    onJumpToScan()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .bold))
                        Text("Scan your kitchen")
                            .font(FridjFont.size(15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(Color.fridjOrange,
                                in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous))
                }
                .padding(.top, FridjSpacing.sm)
            }
        }
        .padding(.horizontal, FridjSpacing.lg)
    }

    // MARK: Card (unchanged)

    private func card(_ recipe: Recipe) -> some View {
        let isOpen = expanded == recipe.id
        let isFav = favorites.isFavorite(recipe)
        return VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack(alignment: .top, spacing: 10) {
                Text(recipe.name)
                    .font(FridjFont.size(18, weight: .bold))
                    .foregroundColor(.fridjText)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                        _ = favorites.toggle(recipe)
                    }
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isFav ? .fridjCoral : .fridjText.opacity(0.35))
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
        .background(Color(white: 1),
                    in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous))
    }

    // MARK: Undo banner

    private func undoBanner(recipeId: String) -> some View {
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
            .background(Color.fridjText,
                        in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
            .padding(.horizontal, FridjSpacing.lg)
            .padding(.bottom, 30)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .id(recipeId)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showUndoFor)
    }

    private func markCooked(_ recipe: Recipe) {
        let removed = recipe.uses.filter { store.contains($0) }
        guard !removed.isEmpty else { return }
        for name in removed { store.remove(name: name) }
        CookingStore.shared.logToday()
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
    RecipesView(recipes: [])
}
