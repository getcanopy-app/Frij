import SwiftUI

struct PantryView: View {
    @State private var store = PantryStore.shared
    @State private var newItem: String = ""
    @State private var recipes: [Recipe] = []
    @State private var isCooking = false
    @State private var isValidating = false
    @State private var errorText: String?
    @State private var rejectionText: String?
    @State private var showRecipes = false

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FridjSpacing.lg) {
                    header
                    cookButton

                    if let errorText {
                        Text(errorText)
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
                    } else {
                        itemsList
                    }
                }
                .padding(FridjSpacing.lg)
                .padding(.bottom, 120)
            }
        }
        .sheet(isPresented: $showRecipes) {
            RecipesView(recipes: recipes)
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
            Task { await cook() }
        } label: {
            HStack {
                if isCooking { ProgressView().tint(.white) }
                Text(isCooking ? "Cooking up ideas…" : "Get 3 dinners from this")
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
        .disabled(store.items.isEmpty || isCooking)
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

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            Text("\(store.items.count) items")
                .font(FridjFont.size(13))
                .foregroundColor(.fridjText.opacity(0.5))

            ForEach(store.items) { item in
                HStack {
                    Circle()
                        .fill(dotColor(for: item.source))
                        .frame(width: 8, height: 8)
                    Text(item.name)
                        .font(FridjFont.size(15, weight: .medium))
                        .foregroundColor(.fridjText)
                    if item.source == .default {
                        Text("default")
                            .font(FridjFont.size(11, weight: .bold))
                            .foregroundColor(.fridjText.opacity(0.4))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Color.fridjText.opacity(0.08), in: Capsule())
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            store.remove(id: item.id)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.fridjText.opacity(0.25))
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Color(white: 1), in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
            }
        }
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

    private func dotColor(for source: PantryItem.Source) -> Color {
        switch source {
        case .scanned: return .fridjGreen
        case .manual:  return .fridjOrange
        case .default: return .fridjText.opacity(0.3)
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

    private func cook() async {
        errorText = nil
        isCooking = true
        do {
            recipes = try await FrijAPI.recipes(ingredients: store.allNames)
            showRecipes = true
        } catch {
            errorText = error.localizedDescription
        }
        isCooking = false
    }
}

#Preview {
    PantryView()
}
