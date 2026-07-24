import SwiftUI

struct PantryView: View {
    @State private var store = PantryStore.shared
    @State private var grocery = GroceryStore.shared
    @Bindable private var session = ScanSession.shared
    @State private var newItem: String = ""
    @State private var isValidating = false
    @State private var rejectionText: String?
    // A parsed multi-item list awaiting the user's confirmation before it lands
    // in the pantry. Empty the rest of the time.
    @State private var pendingItems: [String] = []
    @FocusState private var addFocused: Bool
    @State private var speech = SpeechCapture()
    @State private var isEditing = false
    // Per-session choice, not a saved preference — you pick it when you're
    // deciding what to make, so it resets each visit.
    @State private var isDessert = false
    // Empty means "cook with everything" — the original behaviour, so someone
    // who never discovers tap-to-pick gets exactly what they got before.
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FridjSpacing.lg) {
                    header
                    modeToggle
                    cookButton

                    if let err = session.cookError {
                        Text(err)
                            .font(FridjFont.size(14))
                            .foregroundColor(.fridjCoral)
                    }

                    addRow

                    if let rejectionText {
                        Text(rejectionText)
                            .font(FridjFont.size(13))
                            .foregroundColor(.fridjCoral)
                    }

                    if !pendingItems.isEmpty {
                        pendingConfirm
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: -6)),
                                removal: .opacity
                            ))
                    }

                    if store.items.isEmpty {
                        emptyState
                            .transition(.opacity)
                    } else {
                        itemsList
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 12)),
                                removal: .opacity
                            ))
                    }

                    if grocery.hasItems {
                        grocerySection
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 16)),
                                removal: .opacity
                            ))
                    }
                }
                .padding(FridjSpacing.lg)
                .padding(.bottom, 120)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: store.items.isEmpty)
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: grocery.hasItems)
            }
            // Native keyboard dismissal: drag the list down to lower it (like
            // iMessage), or tap anywhere off the field.
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { addFocused = false }
        }
        .sheet(isPresented: $session.showRecipes) {
            RecipesView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your kitchen")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Everything Frij knows you have.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.5))
        }
        .padding(.top, 60)
    }

    /// Dinner is green, dessert is coral — the screen's whole accent shifts so
    /// the mode is felt at a glance, not just read.
    private var accent: Color { isDessert ? .fridjCoral : .fridjGreen }

    /// One chip rather than a two-up switch. Dinner is the everyday case, so it
    /// is the unmarked default and gets no control at all; dessert is the
    /// occasional detour you opt into. A 50/50 segmented control claimed the two
    /// were equally likely, which they aren't, and it crowded the cook button.
    ///
    /// A single chip is unambiguous here because the cook button underneath
    /// always states the current mode in words.
    ///
    /// Always coral, never `accent`: the chip advertises desserts, so in dinner
    /// mode it reads as coral-on-cream against a green screen — which is what
    /// makes it legible as "somewhere else you can go".
    private var modeToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isDessert.toggle() }
        } label: {
            HStack(spacing: 5) {
                Text("🍰").font(.system(size: 12))
                Text("Desserts").font(FridjFont.size(13, weight: .bold))
            }
            .foregroundColor(isDessert ? .white : .fridjCoral)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(isDessert ? Color.fridjCoral : Color(white: 1), in: Capsule())
            .overlay(
                Capsule().stroke(Color.fridjCoral.opacity(isDessert ? 0 : 0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Selection wins when there is one; otherwise the whole pantry goes over.
    private var cookIngredients: [String] {
        guard !selectedIDs.isEmpty else { return store.allNames }
        return store.items.filter { selectedIDs.contains($0.id) }.map(\.name)
    }

    private var cookButtonTitle: String {
        if session.isCooking { return "Cooking up ideas…" }
        guard !selectedIDs.isEmpty else {
            return isDessert ? "Get 3 desserts from this" : "Get 3 dinners from this"
        }
        return isDessert
            ? "Dessert from these \(selectedIDs.count)"
            : "Cook with these \(selectedIDs.count)"
    }

    private var cookButton: some View {
        Button {
            session.cook(ingredients: cookIngredients, mode: isDessert ? "dessert" : "dinner")
        } label: {
            HStack {
                if session.isCooking { ProgressView().tint(.white) }
                Text(cookButtonTitle)
                    .font(FridjFont.size(17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                store.items.isEmpty ? Color.fridjText.opacity(0.3) : accent,
                in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous)
            )
        }
        .disabled(store.items.isEmpty || session.isCooking)
        .animation(.easeOut(duration: 0.18), value: selectedIDs.count)
    }

    // Shown after a typed or dictated phrase parses into multiple items: the
    // "here's what I heard, tap to remove anything wrong" checkpoint. Uses the
    // screen's accent so it sits with whatever mode is active.
    private var pendingConfirm: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            Text("Add these? Tap any to remove.")
                .font(FridjFont.size(13, weight: .medium))
                .foregroundColor(.fridjText.opacity(0.6))

            FlowLayout(spacing: 7) {
                ForEach(pendingItems, id: \.self) { item in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            pendingItems.removeAll { $0 == item }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(item).font(FridjFont.size(13, weight: .semibold))
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(accent)
                        .padding(.horizontal, 11).padding(.vertical, 7)
                        .background(accent.opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button {
                    let toAdd = pendingItems
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        for name in toAdd { store.addLocal(name: name, source: .manual) }
                        pendingItems = []
                    }
                } label: {
                    Text("Add \(pendingItems.count)")
                        .font(FridjFont.size(15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(accent, in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pendingItems = [] }
                } label: {
                    Text("Cancel")
                        .font(FridjFont.size(15, weight: .bold))
                        .foregroundColor(.fridjText.opacity(0.5))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FridjSpacing.md)
        .background(Color(white: 1), in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous)
                .stroke(Color.fridjText.opacity(0.08), lineWidth: 1)
        )
    }

    private var addRow: some View {
        ZStack {
            if speech.isListening {
                listeningPanel
                    // Springs up from where the field was, with a little overshoot.
                    .transition(.scale(scale: 0.9, anchor: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .offset(y: 8)))
            } else {
                HStack {
                    TextField("add ingredients — type or speak", text: $newItem)
                        .font(FridjFont.size(15))
                        .focused($addFocused)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color(white: 1), in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                        .onSubmit { Task { await addItem() } }
                        .disabled(isValidating)

                    trailingControl
                }
                .transition(.scale(scale: 0.94).combined(with: .opacity))
            }
        }
        // Low damping = the gentle Duolingo bounce as the pill settles.
        .animation(.spring(response: 0.42, dampingFraction: 0.68), value: speech.isListening)
        // A light tap of haptic on both start and stop — the Duolingo touch.
        .sensoryFeedback(.impact(weight: .light), trigger: speech.isListening)
    }

    // Empty field → mic (say a list); typed text → Add; mid-parse → spinner.
    @ViewBuilder
    private var trailingControl: some View {
        if isValidating {
            ProgressView().tint(accent).frame(width: 52, height: 46)
        } else if newItem.trimmingCharacters(in: .whitespaces).isEmpty {
            micButton
        } else {
            addButton
        }
    }

    private var micButton: some View {
        Button { Task { await startListening() } } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(accent, in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var addButton: some View {
        Button { Task { await addItem() } } label: {
            Text("Add")
                .font(FridjFont.size(15, weight: .bold))
                .foregroundColor(accent)
                .padding(.horizontal, 18).padding(.vertical, 12)
                // A tint rather than a fill: Add is a small utility action and
                // shouldn't compete with the cook button. The outline carries the
                // definition — a 15% fill of the sage green all but disappears
                // against cream, while the same 15% of coral reads fine.
                .background(accent.opacity(0.15), in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // The "listening" state, modelled on the reference: live transcript above a
    // dark pill with an animated waveform and a stop button. Replaces the add
    // row while recording, so it never covers the screen like a keyboard.
    private var listeningPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(speech.transcript.isEmpty ? "Listening…" : speech.transcript)
                .font(FridjFont.size(15, weight: .semibold))
                .foregroundColor(speech.transcript.isEmpty ? .fridjText.opacity(0.35) : .fridjText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(.easeOut(duration: 0.12), value: speech.transcript)

            HStack(spacing: 12) {
                WaveformView()
                Spacer()
                Button { stopListening() } label: {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, 16).padding(.trailing, 9).padding(.vertical, 9)
            .background(Color.fridjDark, in: Capsule())
        }
        .padding(FridjSpacing.md)
        .background(Color(white: 1), in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous)
                .stroke(Color.fridjText.opacity(0.08), lineWidth: 1)
        )
    }

    private func startListening() async {
        rejectionText = nil
        addFocused = false
        await speech.start()
        switch speech.status {
        case .denied:
            rejectionText = "Frij needs microphone and speech access to listen — turn them on in Settings."
        case .unavailable:
            rejectionText = "Voice input isn't available right now — try typing instead."
        default:
            break
        }
    }

    private func stopListening() {
        speech.stop()
        let text = speech.transcript
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task { await ingest(text) }
    }

    // Items that have gone unseen long enough to be worth cooking first.
    // Most urgent leads, since that's the whole point of surfacing them.
    private var useSoonItems: [PantryItem] {
        store.items
            .filter { $0.freshnessWarning != .none }
            .sorted { urgency($0.freshnessWarning) > urgency($1.freshnessWarning) }
    }

    // Everything else, bucketed into kitchen sections. Empty groups are dropped
    // so a pantry of four staples doesn't render four empty headers.
    private var groupedItems: [(category: PantryCategory, items: [PantryItem])] {
        let rest = store.items.filter { $0.freshnessWarning == .none }
        let buckets = Dictionary(grouping: rest) { PantryCategory.classify($0.name) }
        return PantryCategory.allCases.compactMap { category in
            guard let items = buckets[category], !items.isEmpty else { return nil }
            return (category, items.sorted { $0.name < $1.name })
        }
    }

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.md) {
            HStack(spacing: 12) {
                Text(countLabel)
                    .font(FridjFont.size(13))
                    .foregroundColor(.fridjText.opacity(0.5))

                Spacer()

                if !selectedIDs.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selectedIDs.removeAll() }
                    } label: {
                        Text("Clear")
                            .font(FridjFont.size(13, weight: .bold))
                            .foregroundColor(.fridjText.opacity(0.45))
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        isEditing.toggle()
                        // Editing and picking are different intents; don't leave
                        // a stale selection driving the cook button.
                        if isEditing { selectedIDs.removeAll() }
                    }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(FridjFont.size(13, weight: .bold))
                        .foregroundColor(isEditing ? .fridjGreen : .fridjOrange)
                }
            }

            if !useSoonItems.isEmpty {
                useSoonSection
            }

            ForEach(groupedItems, id: \.category) { group in
                chipSection(title: group.category.title,
                            tint: .fridjText.opacity(0.45),
                            items: group.items)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: store.items.count)
    }

    private func chipSection(title: String, tint: Color, items: [PantryItem]) -> some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            Text(title.uppercased())
                .font(FridjFont.size(10, weight: .bold))
                .tracking(0.9)
                .foregroundColor(tint)

            FlowLayout(spacing: 7) {
                ForEach(items) { item in
                    chip(for: item)
                }
            }
        }
    }

    // Same as a chip section, but its header carries a "Cook these" shortcut —
    // Frij's whole reason for being, cooking from what's about to spoil. It
    // sends the full pantry with the expiring items flagged so the dishes get
    // built around them without going thin.
    private var useSoonSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("USE SOON")
                    .font(FridjFont.size(10, weight: .bold))
                    .tracking(0.9)
                    .foregroundColor(.fridjCoral)
                Spacer()
                Button {
                    session.cook(ingredients: store.allNames,
                                 mode: isDessert ? "dessert" : "dinner",
                                 prioritize: useSoonItems.map(\.name))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 10, weight: .bold))
                        Text("Cook these").font(FridjFont.size(12, weight: .bold))
                    }
                    .foregroundColor(.fridjCoral)
                    .opacity(session.canCook ? 1 : 0.4)
                }
                .disabled(!session.canCook)
            }

            FlowLayout(spacing: 7) {
                ForEach(useSoonItems) { item in
                    chip(for: item)
                }
            }
        }
    }

    private func chip(for item: PantryItem) -> some View {
        let warning = item.freshnessWarning
        let isWarning = warning != .none
        let accent = freshnessColor(warning)
        let isSelected = selectedIDs.contains(item.id)

        return HStack(spacing: 5) {
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .transition(.scale.combined(with: .opacity))
            }

            Text(item.name)
                .font(FridjFont.size(13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .fridjText)

            if isWarning {
                Text("\(item.daysSinceLastSeen)d")
                    .font(FridjFont.size(10, weight: .bold))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : accent)
            }

            if isEditing {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedIDs.remove(item.id)
                        store.remove(id: item.id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.fridjText.opacity(0.45))
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(chipFill(isSelected: isSelected, isWarning: isWarning, accent: accent), in: Capsule())
        .overlay {
            Capsule()
                .stroke(chipStroke(isSelected: isSelected, isWarning: isWarning, accent: accent),
                        lineWidth: 1)
        }
        .contentShape(Capsule())
        .onTapGesture {
            // While editing, the ✕ owns the chip — tapping the body shouldn't
            // also start building a selection.
            guard !isEditing else { return }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                if isSelected { selectedIDs.remove(item.id) } else { selectedIDs.insert(item.id) }
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)),
            removal: .opacity.combined(with: .scale(scale: 0.9))
        ))
    }

    private func chipFill(isSelected: Bool, isWarning: Bool, accent: Color) -> Color {
        if isSelected { return .fridjGreen }
        return isWarning ? accent.opacity(0.10) : Color(white: 1)
    }

    private func chipStroke(isSelected: Bool, isWarning: Bool, accent: Color) -> Color {
        if isSelected { return .fridjGreen }
        return isWarning ? accent.opacity(0.45) : Color.fridjText.opacity(0.10)
    }

    private var countLabel: String {
        if !selectedIDs.isEmpty { return "\(selectedIDs.count) selected" }
        if isEditing { return "\(store.items.count) items" }
        return "\(store.items.count) items · tap to pick"
    }

    private func urgency(_ warning: PantryItem.FreshnessWarning) -> Int {
        switch warning {
        case .none:  return 0
        case .watch: return 1
        case .old:   return 2
        case .stale: return 3
        }
    }

    private var grocerySection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("Grocery list")
                    .font(FridjFont.style(.title, weight: .bold))
                    .foregroundColor(.fridjText)
                Spacer()
                Text("\(grocery.uncheckedCount) left")
                    .font(FridjFont.size(13))
                    .foregroundColor(.fridjText.opacity(0.4))
                if grocery.items.contains(where: { $0.isChecked }) {
                    Button("Clear checked") {
                        withAnimation(.easeOut(duration: 0.2)) {
                            grocery.clearChecked()
                        }
                    }
                    .font(FridjFont.size(13, weight: .bold))
                    .foregroundColor(.fridjCoral)
                }
            }

            ForEach(grocery.items) { item in
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            grocery.toggle(item)
                        }
                    } label: {
                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(item.isChecked ? .fridjGreen : .fridjText.opacity(0.25))
                    }

                    Text(item.name)
                        .font(FridjFont.size(15))
                        .foregroundColor(item.isChecked ? .fridjText.opacity(0.35) : .fridjText)
                        .strikethrough(item.isChecked, color: .fridjText.opacity(0.35))
                        .animation(.easeOut(duration: 0.15), value: item.isChecked)

                    Spacer()

                    if item.isChecked {
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                store.addLocal(name: item.name, source: .manual)
                                grocery.remove(item)
                            }
                        } label: {
                            Text("Add to pantry")
                                .font(FridjFont.size(11, weight: .bold))
                                .foregroundColor(.fridjGreen)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.fridjMint.opacity(0.5), in: Capsule())
                        }
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            grocery.remove(item)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.fridjText.opacity(0.2))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(white: 1), in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: grocery.items.count)
    }

    private var emptyState: some View {
        VStack(spacing: FridjSpacing.sm) {
            Image(systemName: "refrigerator")
                .font(.system(size: 48))
                .foregroundColor(.fridjOrange.opacity(0.6))
            Text("Your pantry is empty")
                .font(FridjFont.size(16, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Scan your fridge or add items above.")
                .font(FridjFont.size(13))
                .foregroundColor(.fridjText.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func freshnessColor(_ warning: PantryItem.FreshnessWarning) -> Color {
        switch warning {
        case .none:  return .clear
        case .watch: return Color(red: 0.95, green: 0.75, blue: 0.1)
        case .old:   return .fridjOrange
        case .stale: return .fridjCoral
        }
    }

    private func addItem() async { await ingest(newItem) }

    // Shared by the typed field and voice: one phrase in, parsed and either
    // added (single) or handed to the confirm card (multiple).
    private func ingest(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        rejectionText = nil
        isValidating = true
        defer { isValidating = false }

        let items: [String]
        do {
            items = try await FrijAPI.parseIngredients(text: text)
        } catch {
            // Network hiccup: don't strand the user — add the raw text as one
            // item and let validation happen next time.
            store.addLocal(name: text, source: .manual)
            newItem = ""
            return
        }

        switch items.count {
        case 0:
            rejectionText = "Didn't catch any food in that — try again."
        case 1:
            // A single clean item needs no confirmation — same feel as before.
            store.addLocal(name: items[0], source: .manual)
            newItem = ""
        default:
            // A spoken or typed list: show it back for a quick check before
            // committing, per "here's what I heard, tap to remove anything wrong".
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                pendingItems = items
                newItem = ""
            }
        }
    }
}

/// Decorative "listening" bars. Not tied to real amplitude — that would mean
/// hopping the audio thread to the main actor for every buffer — just a steady
/// animation while the recognizer runs.
private struct WaveformView: View {
    @State private var animating = false
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: animating ? 20 : 6)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i % 6) * 0.1),
                        value: animating)
            }
        }
        .frame(height: 22)
        .onAppear { animating = true }
    }
}

#Preview {
    PantryView()
}
