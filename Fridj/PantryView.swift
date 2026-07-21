import SwiftUI

struct PantryView: View {
    @State private var store = PantryStore.shared
    @State private var grocery = GroceryStore.shared
    @Bindable private var session = ScanSession.shared
    @State private var newItem: String = ""
    @State private var isValidating = false
    @State private var rejectionText: String?
    @State private var isEditing = false

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FridjSpacing.lg) {
                    header
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

    private var cookButton: some View {
        Button {
            session.cook(ingredients: store.allNames)
        } label: {
            HStack {
                if session.isCooking { ProgressView().tint(.white) }
                Text(session.isCooking ? "Cooking up ideas…" : "Get 3 dinners from this")
                    .font(FridjFont.size(17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                store.items.isEmpty ? Color.fridjText.opacity(0.3) : Color.fridjGreen,
                in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous)
            )
        }
        .disabled(store.items.isEmpty || session.isCooking)
    }

    private var addRow: some View {
        HStack {
            TextField("add an ingredient", text: $newItem)
                .font(FridjFont.size(15))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(white: 1), in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
                .onSubmit { Task { await addItem() } }
                .disabled(isValidating)
            Button {
                Task { await addItem() }
            } label: {
                HStack(spacing: 6) {
                    if isValidating { ProgressView().tint(.white).scaleEffect(0.8) }
                    Text(isValidating ? "Checking" : "Add")
                        .font(FridjFont.size(15, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .background(Color.fridjText, in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
            }
            .disabled(isValidating)
        }
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
            HStack {
                Text("\(store.items.count) items")
                    .font(FridjFont.size(13))
                    .foregroundColor(.fridjText.opacity(0.5))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        isEditing.toggle()
                    }
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(FridjFont.size(13, weight: .bold))
                        .foregroundColor(isEditing ? .fridjGreen : .fridjOrange)
                }
            }

            if !useSoonItems.isEmpty {
                chipSection(title: "Use soon", tint: .fridjCoral, items: useSoonItems)
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

    private func chip(for item: PantryItem) -> some View {
        let warning = item.freshnessWarning
        let isWarning = warning != .none
        let accent = freshnessColor(warning)

        return HStack(spacing: 5) {
            Text(item.name)
                .font(FridjFont.size(13, weight: .semibold))
                .foregroundColor(.fridjText)

            if isWarning {
                Text("\(item.daysSinceLastSeen)d")
                    .font(FridjFont.size(10, weight: .bold))
                    .foregroundColor(accent)
            }

            if isEditing {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
        .background(isWarning ? accent.opacity(0.10) : Color(white: 1), in: Capsule())
        .overlay {
            Capsule()
                .stroke(isWarning ? accent.opacity(0.45) : Color.fridjText.opacity(0.10),
                        lineWidth: 1)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.9)),
            removal: .opacity.combined(with: .scale(scale: 0.9))
        ))
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

    private func addItem() async {
        let v = newItem.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        rejectionText = nil
        isValidating = true
        let result = await store.addValidated(name: v)
        isValidating = false
        if result.valid {
            newItem = ""
        } else {
            rejectionText = "Hmm, \"\(v)\" doesn't look like a food item. (\(result.reason ?? "not recognized"))"
        }
    }
}

#Preview {
    PantryView()
}
