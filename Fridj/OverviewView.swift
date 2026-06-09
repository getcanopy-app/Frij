import SwiftUI

// Panel-only — coordinator owns photo background and blur overlay.
struct OverviewView: View {
    let onDismiss: () -> Void

    @State private var store = PantryStore.shared
    @State private var session = ScanSession.shared
    @State private var showAddField = false
    @State private var newItem = ""
    @State private var isValidating = false
    @State private var rejectionText: String?

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                mainCard
                    .padding(.horizontal, 16)
                    .padding(.top, 120)
                    .padding(.bottom, 120)
            }

            // Top bar
            HStack {
                closeButton
                Spacer()
                Text("Overview")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: Circle())
                .environment(\.colorScheme, .dark)
        }
    }

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            macrosHeader
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider().overlay(Color.white.opacity(0.15))
                .padding(.horizontal, 16)

            ingredientCountRow
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

            if showAddField {
                addItemRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let rejection = rejectionText {
                Text(rejection)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.fridjCoral)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

            ingredientGrid
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            Divider().overlay(Color.white.opacity(0.15))
                .padding(.horizontal, 16)

            generateButton
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.72))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .environment(\.colorScheme, .dark)
    }

    // MARK: Macros header (decorative only)

    private var macrosHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.fridjOrange.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.fridjOrange)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Macros")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Auto-detected ingredients")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var ingredientCountRow: some View {
        HStack {
            Text("\(store.items.count) Ingredients")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAddField.toggle()
                    if !showAddField { newItem = ""; rejectionText = nil }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("Add")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color.fridjOrange)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.fridjOrange.opacity(0.15), in: Capsule())
            }
        }
    }

    private var addItemRow: some View {
        HStack(spacing: 8) {
            TextField("add an ingredient...", text: $newItem)
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Color.white.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .onSubmit { Task { await submitNewItem() } }
                .disabled(isValidating)

            Button {
                Task { await submitNewItem() }
            } label: {
                Group {
                    if isValidating {
                        ProgressView().tint(.white).scaleEffect(0.75)
                    } else {
                        Text("Add")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 52, height: 36)
                .background(Color.fridjOrange,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(isValidating)
        }
    }

    private var ingredientGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(store.items) { item in
                HStack {
                    Text(item.name.capitalized)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            store.remove(id: item.id)
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.white.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                }
            }
        }
    }

    private var generateButton: some View {
        Button {
            session.cook(ingredients: store.allNames)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Generate meal ideas")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("Get personalized recipes")
                        .font(.system(size: 12, design: .rounded))
                        .opacity(0.7)
                }
                Spacer()
                if session.isCooking {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(
                store.items.isEmpty ? Color.fridjText.opacity(0.3) : Color.fridjGreen,
                in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous)
            )
        }
        .disabled(store.items.isEmpty || session.isCooking)
    }

    private func submitNewItem() async {
        let v = newItem.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        rejectionText = nil
        isValidating = true
        let result = await store.addValidated(name: v)
        isValidating = false
        if result.valid {
            newItem = ""
        } else {
            rejectionText = "\"\(v)\" doesn't look like a food item."
        }
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        OverviewView(onDismiss: {})
    }
}
