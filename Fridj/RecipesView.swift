import SwiftUI

struct RecipesView: View {
    @State private var selectedRecipe: Recipe?
    @State private var store = PantryStore.shared
    @State private var favorites = FavoritesStore.shared
    @State private var history = RecipeHistoryStore.shared
    @Bindable private var session = ScanSession.shared
    @State private var sub = SubscriptionManager.shared
    @State private var usage = UsageStore.shared

    @State private var lastRemoved: [String] = []
    @State private var showUndoFor: String?
    // The dish behind the current undo banner, so Undo also reverses the
    // "cooked" taste signal — not just the pantry removal.
    @State private var lastCooked: Recipe?
    // Rendered Fridge Roast card awaiting the share sheet.
    @State private var roastImage: UIImage?
    // Paste-a-link recipe import (TikTok/IG/YouTube).
    @State private var showImport = false
    // Photos-style selection mode: long-press any saved/history meal to enter,
    // tap toggles checkmarks, floating bar deletes the batch.
    @State private var isSelecting = false
    @State private var selectedForDelete: Set<String> = []
    // The item currently pressed-and-held — pops up slightly so the press
    // visibly registers before selection mode engages.
    @State private var pressedID: String?

    var onJumpToScan: (() -> Void)? = nil

    private var recipes: [Recipe] { session.recipes }
    private var hasSaved: Bool { !favorites.recipes.isEmpty }
    private var hasFresh: Bool { !recipes.isEmpty }

    // Meals seen before that aren't in tonight's fresh batch or already saved —
    // the "don't lose it" archive. Capped so the page stays tight.
    private var recentGenerated: [Recipe] {
        let shownIDs = Set(recipes.map(\.id))
        let savedIDs = Set(favorites.recipes.map(\.id))
        return Array(history.recipes
            .filter { !shownIDs.contains($0.id) && !savedIDs.contains($0.id) }
            .prefix(12))
    }
    private var hasHistory: Bool { !recentGenerated.isEmpty }
    private var isCompletelyEmpty: Bool { !hasSaved && !hasFresh && !hasHistory }

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
                        // Freshest first: tonight's new ideas lead, the archive
                        // of already-secured saves sits below in compact rows.
                        if hasFresh {
                            tonightSection
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 16)),
                                    removal: .opacity
                                ))
                        }
                        if hasSaved {
                            savedSection
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 16)),
                                    removal: .opacity
                                ))
                        }
                        if hasHistory {
                            recentlyGeneratedSection
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
                // Tap on any empty space while selecting = smooth exit; item
                // taps win their own gesture, so toggling still works.
                .onTapGesture { if isSelecting { exitSelection() } }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 24)),
                    removal: .opacity
                ))
            }

            if let recipeId = showUndoFor, !lastRemoved.isEmpty {
                undoBanner(recipeId: recipeId)
            }

            if isSelecting {
                selectionBar
            }
        }
        .animation(.easeOut(duration: 0.45), value: session.isCooking)
        .sensoryFeedback(.impact(weight: .light), trigger: pressedID) { _, new in new != nil }
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe) {
                markCooked(recipe)
                selectedRecipe = nil
            }
        }
        .sheet(isPresented: Binding(
            get: { roastImage != nil },
            set: { if !$0 { roastImage = nil } }
        )) {
            if let roastImage {
                ShareSheet(items: [roastImage])
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showImport) {
            ImportLinkSheet { recipe in
                // Imported recipes land in Saved (that's the "all in one
                // place" promise), then open for a look.
                if !favorites.isFavorite(recipe) { _ = favorites.toggle(recipe) }
                showImport = false
                selectedRecipe = recipe
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

            Button("Cancel") { session.cancelCook() }
                .font(FridjFont.size(15, weight: .bold))
                .foregroundColor(.fridjText.opacity(0.5))
                .padding(.top, FridjSpacing.sm)
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
                // Import a recipe from a TikTok/IG/YouTube link into Saved.
                Button { showImport = true } label: {
                    Image(systemName: "link.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.fridjText.opacity(0.45))
                }
                .buttonStyle(.plain)
                Text("\(favorites.recipes.count)")
                    .font(FridjFont.size(14, weight: .bold))
                    .foregroundColor(.fridjText.opacity(0.4))
            }
            // A horizontal photo shelf: the images stay big and immediate (the
            // whole point of generating them), but the section costs a FIXED
            // height whether there are 3 saves or 30 — so it can never bury
            // tonight's fresh ideas. Bleeds edge-to-edge so tiles peek past the
            // screen edge, which is what signals "scroll me."
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: FridjSpacing.sm) {
                    ForEach(favorites.recipes) { recipe in
                        // The native Apple pattern (Photos / Home Screen):
                        // press-and-hold lifts the tile to show selection,
                        // then the system platter offers a red Remove.
                        savedTile(recipe,
                                  selecting: isSelecting,
                                  selected: selectedForDelete.contains(recipe.id))
                            .onTapGesture {
                                if isSelecting { toggleSelection(recipe) } else { selectedRecipe = recipe }
                            }
                            // Press acknowledgment: the tile pops up under the
                            // finger, springs back on release, and selection
                            // mode engages.
                            .scaleEffect(pressedID == recipe.id ? 1.04 : 1)
                            .zIndex(pressedID == recipe.id ? 1 : 0)
                            .animation(.spring(response: 0.28, dampingFraction: 0.55), value: pressedID)
                            .onLongPressGesture(minimumDuration: 0.3) {
                                enterSelection(with: recipe)
                            } onPressingChanged: { pressing in
                                pressedID = pressing ? recipe.id : nil
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }
                .padding(.horizontal, FridjSpacing.lg)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: favorites.recipes.count)
            }
            .padding(.horizontal, -FridjSpacing.lg)
            // The press-pop scales tiles past the shelf bounds — without this
            // the ScrollView shears the photo and the "30 min" line. Let the
            // popped tile draw outside; zIndex keeps it above neighbors.
            .scrollClipDisabled()
        }
    }

    // One tile on the saved shelf — photo-led, name + time under it, heart to
    // un-save floating on the image like everywhere else.
    private func savedTile(_ recipe: Recipe, selecting: Bool = false, selected: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            MealImageView(dish: recipe.name, cornerRadius: 14)
                .frame(width: 150, height: 108)
                // Clip AFTER the frame: scaledToFill inside MealImageView
                // reports an oversized height and would bleed past the tile.
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if !selecting {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                                _ = favorites.toggle(recipe)
                            }
                        } label: {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.fridjCoral)
                                .frame(width: 27, height: 27)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                }
                // Photos-style checkmark, bottom-trailing on the photo.
                .overlay(alignment: .bottomTrailing) {
                    if selecting {
                        selectionBadge(selected: selected)
                            .padding(7)
                    }
                }
                .opacity(selecting && !selected ? 0.8 : 1)
                // Selected = the meal itself glows: crisp orange edge plus a
                // soft warm halo, right where the eye already is.
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.fridjOrange.opacity(selected ? 1 : 0), lineWidth: 2.5)
                )
                .shadow(color: Color.fridjOrange.opacity(selected ? 0.55 : 0),
                        radius: selected ? 10 : 0, x: 0, y: 0)
                .shadow(color: Color.fridjOrange.opacity(selected ? 0.3 : 0),
                        radius: selected ? 20 : 0, x: 0, y: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(FridjFont.size(13, weight: .semibold))
                    .foregroundColor(.fridjText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)  // equal-height tiles
                if !recipe.cookTime.isEmpty {
                    Text(recipe.cookTime)
                        .font(FridjFont.size(11, weight: .medium))
                        .foregroundColor(.fridjText.opacity(0.45))
                }
            }
        }
        .frame(width: 150, alignment: .leading)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }

    // MARK: Tonight

    private var tonightSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("Tonight's options")
                    .font(FridjFont.style(.title, weight: .bold))
                    .foregroundColor(.fridjText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                // Fridge Roast: render the score + tonight's three dishes into
                // a story-sized card and hand it to the share sheet. Local and
                // instant, so no loading state needed.
                Button {
                    let score = FridgeScore.compute(names: store.items.map(\.name))
                    roastImage = FridgeRoastCard.renderImage(score: score, dishes: recipes.map(\.name))
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.fridjText.opacity(0.45))
                }
                .buttonStyle(.plain)
            }

            // Refresh sits with the subtitle rather than the title. Sharing the
            // title row forced "Tonight's options" to wrap onto two lines and
            // left the two controls fighting over the same horizontal space.
            HStack(alignment: .firstTextBaseline) {
                Text("From what's in your kitchen.")
                    .font(FridjFont.size(13))
                    .foregroundColor(.fridjText.opacity(0.5))
                    .lineLimit(1)

                Spacer(minLength: 12)

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
                    .fixedSize()
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
                    .fixedSize()
                }
            }

            ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                // First card is the taste-ranked best fit — badge it only when
                // personalization was in play (a reason came back).
                card(recipe, topPick: index == 0 && recipe.reason != nil)
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

    // MARK: Recently generated (the "don't lose it" archive)

    private var recentlyGeneratedSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("Recently generated")
                    .font(FridjFont.style(.title, weight: .bold))
                    .foregroundColor(.fridjText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer()
                Text("\(recentGenerated.count)")
                    .font(FridjFont.size(14, weight: .bold))
                    .foregroundColor(.fridjText.opacity(0.4))
            }
            VStack(spacing: FridjSpacing.sm) {
                ForEach(recentGenerated) { recipe in
                    historyRow(recipe,
                               selecting: isSelecting,
                               selected: selectedForDelete.contains(recipe.id))
                        .onTapGesture {
                            if isSelecting { toggleSelection(recipe) } else { selectedRecipe = recipe }
                        }
                        .scaleEffect(pressedID == recipe.id ? 1.02 : 1)
                        .zIndex(pressedID == recipe.id ? 1 : 0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.55), value: pressedID)
                        .onLongPressGesture(minimumDuration: 0.3) {
                            enterSelection(with: recipe)
                        } onPressingChanged: { pressing in
                            pressedID = pressing ? recipe.id : nil
                        }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: recentGenerated.count)
        }
    }

    // Compact archive row — smaller than a "tonight" hero card so it reads as
    // history, not a fresh suggestion.
    private func historyRow(_ recipe: Recipe, selecting: Bool = false, selected: Bool = false) -> some View {
        HStack(spacing: 12) {
            if selecting {
                selectionBadge(selected: selected)
            }

            MealImageView(dish: recipe.name, cornerRadius: 12)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.name)
                    .font(FridjFont.size(15, weight: .bold))
                    .foregroundColor(.fridjText)
                    .lineLimit(1)
                if !recipe.cookTime.isEmpty {
                    Text(recipe.cookTime)
                        .font(FridjFont.size(12, weight: .semibold))
                        .foregroundColor(.fridjText.opacity(0.45))
                }
            }

            Spacer(minLength: 8)

            if !selecting {
                let isFav = favorites.isFavorite(recipe)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                        _ = favorites.toggle(recipe)
                    }
                } label: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(isFav ? .fridjCoral : .fridjText.opacity(0.35))
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            selected ? Color.fridjOrange.opacity(0.08) : Color(white: 1),
            in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous)
                .strokeBorder(Color.fridjOrange.opacity(selected ? 0.9 : 0), lineWidth: 2)
        )
        .shadow(color: Color.fridjOrange.opacity(selected ? 0.45 : 0),
                radius: selected ? 12 : 0, x: 0, y: 0)
        .shadow(color: Color.fridjOrange.opacity(selected ? 0.25 : 0),
                radius: selected ? 22 : 0, x: 0, y: 0)
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selected)
    }

    // MARK: Selection mode (Photos-style)

    private func selectionBadge(selected: Bool) -> some View {
        ZStack {
            if selected {
                Circle().fill(Color.fridjOrange)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Circle().fill(.black.opacity(0.2))
                Circle().stroke(.white, lineWidth: 1.6).padding(1)
            }
        }
        .frame(width: 22, height: 22)
        .transition(.scale.combined(with: .opacity))
    }

    private func enterSelection(with recipe: Recipe) {
        guard !isSelecting else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSelecting = true
            selectedForDelete = [recipe.id]
            // The tab bar slides away and the Delete bar takes its place —
            // a mode swap, not two bars fighting for the same bottom edge.
            ScanSession.shared.hidesTabBar = true
        }
    }

    private func toggleSelection(_ recipe: Recipe) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if selectedForDelete.contains(recipe.id) {
                selectedForDelete.remove(recipe.id)
            } else {
                selectedForDelete.insert(recipe.id)
            }
        }
    }

    private func exitSelection() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isSelecting = false
            selectedForDelete = []
            ScanSession.shared.hidesTabBar = false
        }
    }

    private func deleteSelected() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            for recipe in favorites.recipes where selectedForDelete.contains(recipe.id) {
                favorites.remove(recipe)
            }
            for recipe in history.recipes where selectedForDelete.contains(recipe.id) {
                history.remove(recipe)
            }
            isSelecting = false
            selectedForDelete = []
            ScanSession.shared.hidesTabBar = false
        }
    }

    // Floating action bar while selecting: Done on the left, red Delete (N)
    // on the right — Photos' select-then-act, in Frij's dress.
    private var selectionBar: some View {
        VStack {
            Spacer()
            HStack {
                Button("Done") { exitSelection() }
                    .font(FridjFont.size(15, weight: .bold))
                    .foregroundColor(.fridjText.opacity(0.65))
                Spacer()
                Button { deleteSelected() } label: {
                    Text(selectedForDelete.isEmpty ? "Delete" : "Delete (\(selectedForDelete.count))")
                        .font(FridjFont.size(15, weight: .bold))
                        .foregroundColor(selectedForDelete.isEmpty ? .fridjText.opacity(0.35) : .white)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(
                            selectedForDelete.isEmpty ? Color.fridjText.opacity(0.08) : Color.fridjCoral,
                            in: Capsule()
                        )
                }
                .disabled(selectedForDelete.isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(.horizontal, FridjSpacing.lg)
            .padding(.bottom, 30)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .sensoryFeedback(.impact(weight: .light), trigger: isSelecting)
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

            Button { showImport = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Import from TikTok or Instagram")
                        .font(FridjFont.size(14, weight: .semibold))
                }
                .foregroundColor(.fridjText.opacity(0.55))
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, FridjSpacing.lg)
    }

    // MARK: Card

    private func card(_ recipe: Recipe, topPick: Bool = false) -> some View {
        let isFav = favorites.isFavorite(recipe)
        return Button {
            selectedRecipe = recipe
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Heart and cook time float on the photo instead of sharing the
                // title row — three elements competing there squeezed longer
                // recipe names into an awkward wrap.
                MealImageView(dish: recipe.name, cornerRadius: 0)
                    .frame(maxWidth: .infinity)
                    .frame(height: 170)
                    .clipShape(.rect(topLeadingRadius: FridjRadius.recipeCard,
                                    topTrailingRadius: FridjRadius.recipeCard))
                    // "Not for me" — a quiet dismiss that mirrors the heart. Tap
                    // to wave a dish off: it slides away and we learn to show
                    // fewer like it. Deliberately low-contrast so it never
                    // competes with the save.
                    .overlay(alignment: .topLeading) {
                        Button { dismissRecipe(recipe) } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.fridjText.opacity(0.5))
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                                _ = favorites.toggle(recipe)
                            }
                        } label: {
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(isFav ? .fridjCoral : .fridjText.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10, weight: .bold))
                            Text(recipe.cookTime)
                                .font(FridjFont.size(12, weight: .bold))
                        }
                        .foregroundColor(.fridjText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(10)
                    }

                VStack(alignment: .leading, spacing: 9) {
                    // Backend ranks by taste fit (best first); this makes the
                    // ranking legible. Only shown when personalization actually
                    // drove the order — never as empty decoration.
                    if topPick {
                        Text("TOP PICK FOR YOU")
                            .font(FridjFont.size(9, weight: .bold))
                            .tracking(0.9)
                            .foregroundColor(.fridjOrange)
                    }

                    Text(recipe.name)
                        .font(FridjFont.size(18, weight: .bold))
                        .foregroundColor(.fridjText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // The personal "Because you…" note — the moment Frij feels
                    // like it knows you. Only present when a taste profile drove
                    // this pick, so it never shows as empty filler.
                    if let reason = recipe.reason?.trimmingCharacters(in: .whitespaces), !reason.isEmpty {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(FridjFont.size(11, weight: .semibold))
                            Text(reason)
                                .font(FridjFont.size(13, weight: .semibold))
                                .multilineTextAlignment(.leading)
                        }
                        .foregroundColor(.fridjOrange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Progressive disclosure: the card carries only the one
                    // glanceable decision — do I need to shop? — as the same
                    // compact badge the Home cards use (live via PantryMatch).
                    // Silence means cookable now; the full grouped ingredient
                    // breakdown lives one tap deeper in the detail sheet.
                    let missing = PantryMatch.partition(recipe.uses + recipe.needs).need.count
                    if missing > 0 {
                        Text("needs \(missing) item\(missing == 1 ? "" : "s")")
                            .font(FridjFont.size(11, weight: .bold))
                            .foregroundColor(.fridjOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.fridjOrange.opacity(0.14), in: Capsule())
                    }
                }
                .padding(FridjSpacing.md)
            }
            .background(Color(white: 1),
                        in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 9)
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
                    if let cooked = lastCooked { TasteSignalsStore.shared.undoCooked(cooked) }
                    lastCooked = nil
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

    // "Not for me" — record the soft-negative signal and slide the card out.
    // No undo: it's low-stakes (regenerate anytime), and a banner here would
    // clutter the exact minimalism we're protecting.
    private func dismissRecipe(_ recipe: Recipe) {
        TasteSignalsStore.shared.dislike(recipe)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            session.recipes.removeAll { $0.id == recipe.id }
        }
    }

    private func markCooked(_ recipe: Recipe) {
        // Strongest taste signal — record the dish itself, not just the date.
        TasteSignalsStore.shared.logCooked(recipe)
        lastCooked = recipe

        // Uses + needs, not just uses: the stored split is a snapshot, and an
        // ingredient bought since (stored under needs) is in the pantry now —
        // cooking should consume it too. store.contains keeps it exact.
        let removed = (recipe.uses + recipe.needs).filter { store.contains($0) }
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

// MARK: - Import from a link

// Paste a TikTok / Instagram / YouTube link, get it back as a saved recipe.
// Kept deliberately tiny: one field, one button, honest errors.
private struct ImportLinkSheet: View {
    var onImported: (Recipe) -> Void

    @State private var url = ""
    @State private var isImporting = false
    @State private var errorText: String?
    // Drives the paste feedback: field flash + icon morphing to a checkmark.
    @State private var justPasted = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.md) {
            Text("Import a recipe")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Paste a TikTok, Instagram, YouTube or Pinterest link — or the recipe text itself if a post won't import.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.55))

            HStack(alignment: .top, spacing: 8) {
                TextField("Link or recipe text…", text: $url, axis: .vertical)
                    .font(FridjFont.size(15))
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(white: 1), in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                    // A brief warm glow confirms the paste landed in the field.
                    .overlay(
                        RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous)
                            .stroke(Color.fridjOrange.opacity(justPasted ? 0.8 : 0), lineWidth: 2)
                    )

                Button { paste() } label: {
                    Image(systemName: justPasted ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(justPasted ? .white : .fridjOrange)
                        .frame(width: 44, height: 44)
                        .background(justPasted ? Color.fridjOrange : Color.fridjOrange.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
            // Text growth (a pasted caption can be 4 lines) reflows smoothly
            // instead of snapping.
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: url)
            .animation(.easeOut(duration: 0.2), value: justPasted)
            .sensoryFeedback(.success, trigger: justPasted) { _, new in new }

            if let errorText {
                Text(errorText)
                    .font(FridjFont.size(13, weight: .medium))
                    .foregroundColor(.fridjCoral)
            }

            Button {
                Task { await runImport() }
            } label: {
                HStack(spacing: 8) {
                    if isImporting { ProgressView().tint(.white) }
                    Text(isImporting ? "Importing…" : "Import")
                        .font(FridjFont.size(16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    url.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.fridjText.opacity(0.3) : Color.fridjOrange,
                    in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous)
                )
            }
            .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty || isImporting)

            Spacer(minLength: 0)
        }
        .padding(FridjSpacing.lg)
        .background(Color.fridjBg)
        .presentationDetents([.height(320)])
        .presentationCornerRadius(28)
        .onAppear { focused = true }
    }

    // The clipboard often holds a URL OBJECT rather than a string (copying a
    // link out of Instagram does this) — reading only .string silently fails,
    // which read as "the button does nothing." Check both, animate the landing,
    // and say so when the clipboard is genuinely empty.
    private func paste() {
        let pb = UIPasteboard.general
        let pasted = pb.string ?? pb.url?.absoluteString
        guard let pasted, !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorText = "Nothing on your clipboard — copy a link or caption first."
            return
        }
        errorText = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { url = pasted }
        justPasted = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.25)) { justPasted = false }
        }
    }

    private func runImport() async {
        errorText = nil
        isImporting = true
        defer { isImporting = false }
        do {
            let recipe = try await FrijAPI.importRecipe(url)
            onImported(recipe)
        } catch {
            errorText = error.localizedDescription
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
    /// Quick how-to for each side, shown inside "How to make it" when the side
    /// is selected. Two-three loose steps — sides are simple by definition.
    static func steps(for name: String) -> [String] {
        sideSteps[name.lowercased()] ?? []
    }

    private static let sideSteps: [String: [String]] = [
        "antipasto": ["Arrange olives, cured meats, cheese and marinated veg on a plate.", "Drizzle with olive oil and crack some pepper over."],
        "applesauce": ["Peel and chunk apples; simmer with a splash of water until soft.", "Mash with a fork and a pinch of cinnamon."],
        "baked beans": ["Warm the beans in a small pot over medium-low.", "Stir in a little brown sugar or hot sauce to taste."],
        "bruschetta": ["Toast baguette slices until golden.", "Top with diced tomato, garlic, basil and olive oil; salt to finish."],
        "caesar salad": ["Toss chopped romaine with Caesar dressing.", "Top with parmesan and croutons."],
        "chips & salsa": ["Pour salsa into a bowl.", "Open the chips. You've got this."],
        "coleslaw": ["Toss shredded cabbage and carrot with mayo, vinegar, salt and a pinch of sugar.", "Chill 10 minutes so it softens."],
        "corn salad": ["Mix corn, diced tomato, red onion and cilantro.", "Dress with lime juice, olive oil and salt."],
        "cornbread": ["Make the batter per your mix or recipe.", "Bake in a greased pan at 400°F until golden, ~20 min."],
        "crackers": ["Fan them out next to the bowl.", "That's it — they're crackers."],
        "creamed spinach": ["Wilt spinach in butter with garlic.", "Stir in cream and a little parmesan; simmer until thick."],
        "crusty bread": ["Warm the loaf in a 375°F oven for 8-10 minutes.", "Slice thick; serve with butter or olive oil."],
        "cucumber salad": ["Slice cucumbers thin; salt them and let sit 5 minutes.", "Dress with vinegar, a pinch of sugar and dill."],
        "dinner rolls": ["Warm rolls in a 350°F oven for 5-8 minutes.", "Brush with melted butter."],
        "edamame": ["Boil or steam the pods 4-5 minutes.", "Toss with flaky salt while hot."],
        "elote": ["Grill or boil the corn.", "Slather with mayo-crema, sprinkle cotija, chili powder and lime."],
        "french fries": ["Bake frozen fries per the bag — hotter and longer beats soggy.", "Salt immediately out of the oven."],
        "garlic bread": ["Mix soft butter with minced garlic and parsley.", "Spread on split bread; bake at 400°F until golden, ~10 min."],
        "green beans": ["Blanch or steam the beans 3-4 minutes until crisp-tender.", "Toss with butter, salt and a squeeze of lemon."],
        "grilled cheese": ["Butter the outside of two slices; cheese inside.", "Cook in a pan over medium until golden on both sides."],
        "guacamole": ["Mash avocados with lime juice and salt.", "Fold in diced onion, tomato and cilantro."],
        "lemon rice": ["Cook rice as usual.", "Stir in lemon zest, a squeeze of juice and a knob of butter."],
        "mashed potatoes": ["Boil peeled potato chunks until fork-tender.", "Mash with butter, warm milk, salt and pepper."],
        "mexican rice": ["Toast rice in oil until lightly golden.", "Add tomato sauce, broth and cumin; simmer covered until tender."],
        "miso soup": ["Heat dashi or water just below a boil.", "Whisk in miso off the heat; add tofu cubes and scallions."],
        "pickled vegetables": ["Pull them from the jar.", "Arrange prettily; feel accomplished."],
        "pico de gallo": ["Dice tomato, onion and jalapeño; chop cilantro.", "Toss with lime juice and salt."],
        "refried beans": ["Warm the beans in a pan with a splash of water.", "Top with a little cheese while hot."],
        "roasted asparagus": ["Toss spears with olive oil, salt and pepper.", "Roast at 425°F for 10-12 minutes until tips crisp."],
        "roasted potatoes": ["Chunk potatoes; toss with oil, salt and rosemary.", "Roast at 425°F for 25-30 minutes, flipping once."],
        "roasted tomatoes": ["Halve tomatoes; toss with olive oil, salt and garlic.", "Roast cut-side up at 400°F for 20 minutes."],
        "roasted vegetables": ["Chop whatever veg you have into even pieces.", "Toss with oil and salt; roast at 425°F for 20-25 minutes."],
        "sesame noodles": ["Cook noodles and rinse cool.", "Toss with soy sauce, sesame oil, a little peanut butter and scallions."],
        "side salad": ["Toss greens with whatever crunchy veg you have.", "Dress with olive oil, vinegar, salt and pepper."],
        "spring rolls": ["Bake or air-fry frozen rolls per the package.", "Serve with sweet chili sauce."],
        "steamed broccoli": ["Steam florets 4-5 minutes until bright green.", "Hit with salt, butter or a squeeze of lemon."],
        "steamed rice": ["Rinse rice until the water runs clearish.", "Cook 1 part rice to 1.5 parts water — boil, cover, low for 15 min, rest 5."],
        "sweet potato fries": ["Toss wedges with oil, salt and paprika.", "Bake at 425°F ~25 minutes, flipping halfway. They crisp as they cool."],
    ]

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
    // All sides in one swipeable row — swiping replaced the old "rotate"
    // button, so no paging state needed. Deduped by name defensively.
    private var allSides: [SideDish] {
        var seen = Set<String>()
        return SidesSuggester.sets(for: recipe.name).flatMap { $0 }
            .filter { seen.insert($0.name).inserted }
    }

    // Picked sides (they live on the grocery list) whose how-to joins the
    // steps section below.
    private var selectedSides: [SideDish] {
        allSides.filter { side in
            !SidesSuggester.steps(for: side.name).isEmpty &&
            grocery.items.contains { $0.name.caseInsensitiveCompare(side.name) == .orderedSame }
        }
    }

    // A chip isn't dead UI: tap adds the side to the grocery list and the chip
    // settles into a checked mint state (persisted — it reads from the list).
    // Tapping again takes it back off — a toggle, not a one-way door.
    private func sideChip(_ side: SideDish) -> some View {
        let onList = grocery.items.contains {
            $0.name.caseInsensitiveCompare(side.name) == .orderedSame
        }
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if onList {
                    if let item = grocery.items.first(where: {
                        $0.name.caseInsensitiveCompare(side.name) == .orderedSame
                    }) {
                        grocery.remove(item)
                    }
                } else {
                    grocery.add([side.name])
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(side.emoji)
                    .font(.system(size: 17))
                Text(side.name)
                    .font(FridjFont.size(13, weight: .semibold))
                    .foregroundColor(.fridjText.opacity(onList ? 0.6 : 1))
                    .lineLimit(1)
                if onList {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.fridjGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(onList ? Color.fridjMint.opacity(0.45) : Color(white: 1),
                        in: Capsule())
            .overlay(
                Capsule().stroke(
                    onList ? Color.fridjGreen.opacity(0.25) : Color.fridjText.opacity(0.08),
                    lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: onList) { _, new in new }
    }

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

                        if let reason = recipe.reason?.trimmingCharacters(in: .whitespaces), !reason.isEmpty {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(FridjFont.size(13, weight: .semibold))
                                Text(reason)
                                    .font(FridjFont.size(15, weight: .semibold))
                                    .multilineTextAlignment(.leading)
                            }
                            .foregroundColor(.fridjOrange)
                        }

                        // Ingredients — grouped, not merged: standing in a
                        // kitchen you scan "pull from the fridge" and "go buy"
                        // as separate jobs. The split is computed LIVE against
                        // the current pantry (via PantryMatch), never trusted
                        // from when the recipe was created — buy the tortillas
                        // and the recipe notices. Rows render as-is since
                        // imports carry quantities inside the string.
                        let split = PantryMatch.partition(recipe.uses + recipe.needs)
                        let totalIngredients = split.have.count + split.need.count
                        if totalIngredients > 0 {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("Ingredients")
                                        .font(FridjFont.size(18, weight: .bold))
                                        .foregroundColor(.fridjText)
                                    Spacer()
                                    if !split.have.isEmpty {
                                        Text("\(split.have.count) of \(totalIngredients) in stock")
                                            .font(FridjFont.size(12, weight: .bold))
                                            .foregroundColor(.fridjGreen)
                                    }
                                }

                                if !split.have.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("IN YOUR FRIDGE")
                                            .font(FridjFont.size(9, weight: .bold))
                                            .tracking(0.9)
                                            .foregroundColor(.fridjGreen.opacity(0.8))
                                        ForEach(split.have, id: \.self) { item in
                                            HStack(spacing: 9) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.fridjGreen)
                                                let parts = PantryMatch.displaySplit(item)
                                                Text(parts.name)
                                                    .font(FridjFont.size(14))
                                                    .foregroundColor(.fridjText.opacity(0.7))
                                                if let amount = parts.amount {
                                                    Text(amount)
                                                        .font(FridjFont.size(12, weight: .semibold))
                                                        .foregroundColor(.fridjText.opacity(0.4))
                                                }
                                            }
                                        }
                                    }
                                }

                                if !split.need.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(addedToList ? "ON YOUR GROCERY LIST" : "TO BUY")
                                            .font(FridjFont.size(9, weight: .bold))
                                            .tracking(0.9)
                                            .foregroundColor(addedToList ? .fridjGreen.opacity(0.8) : .fridjOrange.opacity(0.75))
                                            .contentTransition(.opacity)
                                        ForEach(split.need, id: \.self) { item in
                                            HStack(spacing: 9) {
                                                Image(systemName: addedToList ? "cart.fill" : "plus")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(addedToList ? .fridjGreen : .fridjOrange)
                                                    .contentTransition(.symbolEffect(.replace))
                                                let parts = PantryMatch.displaySplit(item)
                                                Text(parts.name)
                                                    .font(FridjFont.size(14))
                                                    .foregroundColor(.fridjText.opacity(addedToList ? 0.55 : 1))
                                                if let amount = parts.amount {
                                                    Text(amount)
                                                        .font(FridjFont.size(12, weight: .semibold))
                                                        .foregroundColor(.fridjText.opacity(0.4))
                                                }
                                            }
                                        }

                                        // The add action lives where the missing
                                        // items live. Once tapped it STAYS
                                        // confirmed (no snap-back), and the rows
                                        // above flip to "on your list."
                                        if addedToList {
                                            HStack(spacing: 7) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 13, weight: .semibold))
                                                Text("Added to grocery list")
                                                    .font(FridjFont.size(13, weight: .bold))
                                            }
                                            .foregroundColor(.fridjGreen)
                                            .padding(.horizontal, 13).padding(.vertical, 9)
                                            .background(Color.fridjGreen.opacity(0.1), in: Capsule())
                                            .padding(.top, 4)
                                        } else {
                                            Button {
                                                grocery.add(split.need)
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                    addedToList = true
                                                }
                                            } label: {
                                                HStack(spacing: 7) {
                                                    Image(systemName: "cart.badge.plus")
                                                        .font(.system(size: 13, weight: .semibold))
                                                    Text("Add \(split.need.count) missing to grocery list")
                                                        .font(FridjFont.size(13, weight: .bold))
                                                }
                                                .foregroundColor(.fridjOrange)
                                                .padding(.horizontal, 13).padding(.vertical, 9)
                                                .background(Color.fridjOrange.opacity(0.1), in: Capsule())
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.top, 4)
                                        }
                                    }
                                    .sensoryFeedback(.success, trigger: addedToList) { _, new in new }
                                    // Reopening the sheet later: if everything's
                                    // already on the list, show the settled state
                                    // instead of offering to add again.
                                    .onAppear {
                                        addedToList = split.need.allSatisfy { need in
                                            let n = need.trimmingCharacters(in: .whitespaces).lowercased()
                                            return grocery.items.contains { $0.name.lowercased() == n }
                                        }
                                    }
                                }
                            }
                        }

                        if !allSides.isEmpty {
                            Divider()

                            // One swipeable row of chips — the swipe IS the
                            // "rotate," so the header stays clean. A chip
                            // peeking past the edge signals scrollability.
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Pair it with")
                                    .font(FridjFont.size(17, weight: .bold))
                                    .foregroundColor(.fridjText)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(allSides) { side in
                                            sideChip(side)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.horizontal, -20)
                            }
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

                        // Selected sides join the cooking flow: a compact
                        // how-to block per picked chip, gone the moment the
                        // chip is un-picked (both read from the grocery list).
                        ForEach(selectedSides) { side in
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(side.emoji)  For the \(side.name)")
                                    .font(FridjFont.size(15, weight: .bold))
                                    .foregroundColor(.fridjText)
                                ForEach(Array(SidesSuggester.steps(for: side.name).enumerated()), id: \.offset) { _, step in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(Color.fridjGreen.opacity(0.45))
                                            .frame(width: 7, height: 7)
                                            .padding(.top, 6)
                                        Text(step)
                                            .font(FridjFont.size(14))
                                            .foregroundColor(.fridjText.opacity(0.75))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.top, 4)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 10)),
                                removal: .opacity
                            ))
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
