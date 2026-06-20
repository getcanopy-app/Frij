import SwiftUI

struct RecipesView: View {
    @State private var selectedRecipe: Recipe?
    @State private var store = PantryStore.shared
    @State private var favorites = FavoritesStore.shared
    @Bindable private var session = ScanSession.shared
    @State private var sub = SubscriptionManager.shared
    @State private var usage = UsageStore.shared

    @State private var lastRemoved: [String] = []
    @State private var showUndoFor: String?

    var onJumpToScan: (() -> Void)? = nil

    private var recipes: [Recipe] { session.recipes }
    private var hasSaved: Bool { !favorites.recipes.isEmpty }
    private var hasFresh: Bool { !recipes.isEmpty }
    private var isCompletelyEmpty: Bool { !hasSaved && !hasFresh }

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            if session.isCooking {
                cookingState
                    .transition(.opacity)
            } else if isCompletelyEmpty {
                emptyState
                    .transition(.opacity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: FridjSpacing.lg) {
                        if hasSaved {
                            savedSection
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 16)),
                                    removal: .opacity
                                ))
                        }
                        if hasFresh {
                            tonightSection
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 16)),
                                    removal: .opacity
                                ))
                        }
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: hasFresh)
                    .animation(.spring(response: 0.5, dampingFraction: 0.82), value: hasSaved)
                    .padding(FridjSpacing.lg)
                    .padding(.top, 60)
                    .padding(.bottom, 120)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 24)),
                    removal: .opacity
                ))
            }

            if let recipeId = showUndoFor, !lastRemoved.isEmpty {
                undoBanner(recipeId: recipeId)
            }
        }
        .animation(.easeOut(duration: 0.45), value: session.isCooking)
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe) {
                markCooked(recipe)
                selectedRecipe = nil
            }
        }
    }

    // MARK: Cooking state

    private var cookingState: some View {
        VStack(spacing: FridjSpacing.md) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.fridjOrange)
            Text("Cooking up ideas…")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Looking at what's in your kitchen and finding three dinners you can make tonight.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.horizontal, FridjSpacing.lg)
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

            ForEach(Array(favorites.recipes.enumerated()), id: \.element.id) { index, recipe in
                card(recipe)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 20)),
                        removal: .opacity.combined(with: .offset(y: -10))
                    ))
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.78).delay(Double(index) * 0.07),
                        value: favorites.recipes.count
                    )
            }
        }
    }

    // MARK: Tonight

    private var tonightSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("Tonight's options")
                    .font(FridjFont.style(.title, weight: .bold))
                    .foregroundColor(.fridjText)
                Spacer()
                if session.isPremiumGated {
                    Button { sub.showPaywall = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Frij+")
                                .font(FridjFont.size(13, weight: .bold))
                        }
                        .foregroundColor(.fridjOrange)
                    }
                } else {
                    Button {
                        session.cook(ingredients: store.items.map(\.name))
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                            Text("more options")
                                .font(FridjFont.size(13, weight: .bold))
                            if !sub.isSubscribed && usage.remaining > 0 {
                                Text("· \(usage.remaining) left")
                                    .font(FridjFont.size(11))
                                    .foregroundColor(.fridjOrange.opacity(0.6))
                            }
                        }
                        .foregroundColor(.fridjOrange)
                        .opacity(session.canCook ? 1 : 0.35)
                    }
                    .disabled(!session.canCook)
                }
            }
            .padding(.top, hasSaved ? FridjSpacing.md : 0)

            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                card(recipe)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 24)),
                        removal: .opacity
                    ))
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.8).delay(Double(index) * 0.08),
                        value: recipes.count
                    )
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
                Button { onJumpToScan() } label: {
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

    // MARK: Card

    private func card(_ recipe: Recipe) -> some View {
        let isFav = favorites.isFavorite(recipe)
        return Button {
            selectedRecipe = recipe
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                MealImageView(dish: recipe.name, cornerRadius: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(.rect(topLeadingRadius: FridjRadius.recipeCard,
                                    topTrailingRadius: FridjRadius.recipeCard))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Text(recipe.name)
                            .font(FridjFont.size(18, weight: .bold))
                            .foregroundColor(.fridjText)
                            .multilineTextAlignment(.leading)
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
                }
                .padding(FridjSpacing.md)
            }
            .background(Color(white: 1),
                        in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous))
        }
        .buttonStyle(.plain)
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
                    for name in lastRemoved { store.addLocal(name: name, source: .scanned) }
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
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            CelebrationCoordinator.shared.show(streak: CookingStore.shared.currentStreak)
        }
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

// MARK: - Sides (local, zero API cost)

struct SideDish: Identifiable {
    var id: String { name }
    let name: String
    let emoji: String
}

enum SidesSuggester {
    // Returns pairs of sides to rotate through. All data is local — no API calls.
    static func sets(for recipeName: String) -> [[SideDish]] {
        let pool = pool(for: recipeName.lowercased())
        return stride(from: 0, to: pool.count, by: 2).map { i in
            Array(pool[i..<min(i + 2, pool.count)])
        }
    }

    private static func pool(for lower: String) -> [SideDish] {
        if lower.contains("steak") || lower.contains("beef") || lower.contains("burger") || lower.contains("brisket") || lower.contains("ribeye") {
            return [.init(name: "Mashed Potatoes", emoji: "🥔"), .init(name: "Roasted Asparagus", emoji: "🌿"),
                    .init(name: "French Fries", emoji: "🍟"),   .init(name: "Garlic Bread", emoji: "🥖"),
                    .init(name: "Side Salad", emoji: "🥗"),      .init(name: "Creamed Spinach", emoji: "🌱")]
        }
        if lower.contains("chicken") || lower.contains("turkey") || lower.contains("poultry") {
            return [.init(name: "Steamed Rice", emoji: "🍚"),      .init(name: "Roasted Vegetables", emoji: "🥦"),
                    .init(name: "Coleslaw", emoji: "🥬"),           .init(name: "Sweet Potato Fries", emoji: "🍠"),
                    .init(name: "Green Beans", emoji: "🫛"),        .init(name: "Cornbread", emoji: "🌽")]
        }
        if lower.contains("fish") || lower.contains("salmon") || lower.contains("tuna") || lower.contains("shrimp") || lower.contains("cod") || lower.contains("tilapia") || lower.contains("seafood") {
            return [.init(name: "Lemon Rice", emoji: "🍋"),         .init(name: "Roasted Asparagus", emoji: "🌿"),
                    .init(name: "Corn Salad", emoji: "🌽"),          .init(name: "Garlic Bread", emoji: "🥖"),
                    .init(name: "Coleslaw", emoji: "🥬"),            .init(name: "Roasted Potatoes", emoji: "🥔")]
        }
        if lower.contains("pasta") || lower.contains("spaghetti") || lower.contains("lasagna") || lower.contains("noodle") || lower.contains("linguine") || lower.contains("fettuccine") || lower.contains("penne") {
            return [.init(name: "Garlic Bread", emoji: "🥖"),       .init(name: "Caesar Salad", emoji: "🥗"),
                    .init(name: "Antipasto", emoji: "🫒"),            .init(name: "Roasted Tomatoes", emoji: "🍅"),
                    .init(name: "Side Salad", emoji: "🥗"),           .init(name: "Bruschetta", emoji: "🍞")]
        }
        if lower.contains("soup") || lower.contains("stew") || lower.contains("chili") || lower.contains("chowder") {
            return [.init(name: "Crusty Bread", emoji: "🥖"),       .init(name: "Side Salad", emoji: "🥗"),
                    .init(name: "Grilled Cheese", emoji: "🧀"),      .init(name: "Cornbread", emoji: "🌽"),
                    .init(name: "Crackers", emoji: "🫓"),             .init(name: "Dinner Rolls", emoji: "🍞")]
        }
        if lower.contains("taco") || lower.contains("burrito") || lower.contains("quesadilla") || lower.contains("enchilada") || lower.contains("fajita") {
            return [.init(name: "Mexican Rice", emoji: "🍚"),        .init(name: "Refried Beans", emoji: "🫘"),
                    .init(name: "Guacamole", emoji: "🥑"),            .init(name: "Pico de Gallo", emoji: "🍅"),
                    .init(name: "Elote", emoji: "🌽"),                .init(name: "Chips & Salsa", emoji: "🫔")]
        }
        if lower.contains("curry") || lower.contains("stir") || lower.contains("ramen") || lower.contains("pho") || lower.contains("fried rice") || lower.contains("sushi") || lower.contains("dumpling") {
            return [.init(name: "Spring Rolls", emoji: "🥟"),        .init(name: "Miso Soup", emoji: "🍜"),
                    .init(name: "Edamame", emoji: "🫛"),              .init(name: "Cucumber Salad", emoji: "🥒"),
                    .init(name: "Pickled Vegetables", emoji: "🥬"),   .init(name: "Sesame Noodles", emoji: "🍜")]
        }
        if lower.contains("pork") || lower.contains("ribs") || lower.contains("bacon") || lower.contains("ham") || lower.contains("sausage") {
            return [.init(name: "Applesauce", emoji: "🍎"),          .init(name: "Roasted Potatoes", emoji: "🥔"),
                    .init(name: "Coleslaw", emoji: "🥬"),             .init(name: "Cornbread", emoji: "🌽"),
                    .init(name: "Baked Beans", emoji: "🫘"),          .init(name: "Steamed Broccoli", emoji: "🥦")]
        }
        // Generic fallback — works with anything
        return [.init(name: "Steamed Rice", emoji: "🍚"),    .init(name: "Side Salad", emoji: "🥗"),
                .init(name: "Roasted Vegetables", emoji: "🥦"), .init(name: "Garlic Bread", emoji: "🥖"),
                .init(name: "Mashed Potatoes", emoji: "🥔"),    .init(name: "Steamed Broccoli", emoji: "🥦")]
    }
}

// MARK: - Recipe Detail Sheet

struct RecipeDetailSheet: View {
    let recipe: Recipe
    let onCooked: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var favorites = FavoritesStore.shared
    @State private var grocery = GroceryStore.shared
    @State private var addedToList = false
    @State private var sideSetIndex = 0

    private var sideSets: [[SideDish]] { SidesSuggester.sets(for: recipe.name) }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 4)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    MealImageView(dish: recipe.name, cornerRadius: 0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            Text(recipe.name)
                                .font(FridjFont.size(26, weight: .bold))
                                .foregroundColor(.fridjText)
                            Spacer()
                            let isFav = favorites.isFavorite(recipe)
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                                    _ = favorites.toggle(recipe)
                                }
                            } label: {
                                Image(systemName: isFav ? "heart.fill" : "heart")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(isFav ? .fridjCoral : .fridjText.opacity(0.3))
                            }
                        }

                        Text(recipe.cookTime)
                            .font(FridjFont.size(13, weight: .bold))
                            .foregroundColor(.fridjGreen)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.fridjMint.opacity(0.5), in: Capsule())

                        VStack(alignment: .leading, spacing: 10) {
                            Text("uses " + recipe.uses.joined(separator: ", "))
                                .font(FridjFont.size(14))
                                .foregroundColor(.fridjText.opacity(0.5))
                            if !recipe.needs.isEmpty {
                                Button {
                                    grocery.add(recipe.needs)
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        addedToList = true
                                    }
                                    Task {
                                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                                        addedToList = false
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: addedToList ? "checkmark.circle.fill" : "cart.badge.plus")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(addedToList ? "Added to grocery list" : "Add \(recipe.needs.joined(separator: ", ")) to list")
                                            .font(FridjFont.size(13, weight: .semibold))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    .foregroundColor(addedToList ? .fridjGreen : .fridjOrange)
                                    .padding(.horizontal, 14).padding(.vertical, 10)
                                    .background(
                                        (addedToList ? Color.fridjGreen : Color.fridjOrange).opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if !sideSets.isEmpty {
                            Divider()

                            HStack {
                                Text("Pair it with")
                                    .font(FridjFont.size(17, weight: .bold))
                                    .foregroundColor(.fridjText)
                                Spacer()
                                if sideSets.count > 1 {
                                    Button {
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                                            sideSetIndex = (sideSetIndex + 1) % sideSets.count
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.2.circlepath")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("rotate")
                                                .font(FridjFont.size(12, weight: .bold))
                                        }
                                        .foregroundColor(.fridjOrange)
                                    }
                                }
                            }

                            HStack(spacing: 10) {
                                ForEach(sideSets[sideSetIndex]) { side in
                                    HStack(spacing: 8) {
                                        Text(side.emoji)
                                            .font(.system(size: 20))
                                        Text(side.name)
                                            .font(FridjFont.size(13, weight: .semibold))
                                            .foregroundColor(.fridjText)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12).padding(.vertical, 13)
                                    .background(Color(white: 1),
                                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(Color.fridjText.opacity(0.08), lineWidth: 1)
                                    )
                                }
                            }
                            .id(sideSetIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }

                        Divider()

                        Text("How to make it")
                            .font(FridjFont.size(18, weight: .bold))
                            .foregroundColor(.fridjText)

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                                HStack(alignment: .top, spacing: 14) {
                                    Text("\(idx + 1)")
                                        .font(FridjFont.size(13, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.fridjGreen, in: Circle())
                                    Text(step)
                                        .font(FridjFont.size(15))
                                        .foregroundColor(.fridjText.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 130)
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Button { onCooked() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("I cooked this")
                            .font(FridjFont.size(17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.fridjGreen,
                                in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 36)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.large])
        .presentationCornerRadius(32)
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.fridjBg)
    }
}

#Preview {
    RecipesView()
}
