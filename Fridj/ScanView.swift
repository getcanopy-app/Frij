import SwiftUI
import PhotosUI

// Replaces the "Coming soon" ScanView placeholder.
// Flow: pick a fridge photo -> backend scans it -> user confirms the
// detected items (confidence-driven) -> hands the list to recipes.

struct ScanView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var items: [DetectedItem] = []
    @State private var checked: Set<String> = []          // which items are included
    @State private var newItem: String = ""
    @State private var diet: String = ""
    @State private var isScanning = false
    @State private var errorText: String?
    @State private var recipes: [Recipe] = []
    @State private var isCooking = false
    @State private var showRecipes = false

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: FridjSpacing.lg) {
                    header

                    if let pickedImage {
                        Image(uiImage: pickedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(pickedImage == nil ? "Pick a fridge photo" : "Pick a different photo",
                              systemImage: "photo.on.rectangle")
                            .font(FridjFont.size(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.fridjOrange,
                                        in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous))
                    }

                    if isScanning {
                        HStack(spacing: FridjSpacing.sm) {
                            ProgressView()
                            Text("Reading your fridge…")
                                .font(FridjFont.size(14))
                                .foregroundColor(.fridjText.opacity(0.6))
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .font(FridjFont.size(14))
                            .foregroundColor(.fridjCoral)
                    }

                    if !items.isEmpty {
                        ingredientSection
                        addRow
                        dietField
                        cookButton
                    }
                }
                .padding(FridjSpacing.lg)
                .padding(.bottom, 120)
            }
        }
        .onChange(of: pickerItem) { _, newValue in
            Task { await loadAndScan(newValue) }
        }
        .sheet(isPresented: $showRecipes) {
            RecipesView(recipes: recipes)
        }
    }

    // MARK: pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scan your fridge")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Snap it, confirm what's inside, get dinner.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.5))
        }
        .padding(.top, 60)
    }

    private var ingredientSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            Text("What's inside")
                .font(FridjFont.size(18, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Tap to include or skip. We pre-checked the ones we're sure about.")
                .font(FridjFont.size(13))
                .foregroundColor(.fridjText.opacity(0.5))

            FlowChips(items: items, checked: $checked)
        }
    }

    private var addRow: some View {
        HStack {
            TextField("add something we missed", text: $newItem)
                .font(FridjFont.size(15))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
            Button {
                let v = newItem.lowercased().trimmingCharacters(in: .whitespaces)
                guard !v.isEmpty, !items.contains(where: { $0.item == v }) else { newItem = ""; return }
                items.append(DetectedItem(item: v, confidence: .high))
                checked.insert(v)
                newItem = ""
            } label: {
                Text("Add").font(FridjFont.size(15, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(Color.fridjText, in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
            }
        }
    }

    private var dietField: some View {
        TextField("dietary notes? (optional — high protein, no pork…)", text: $diet)
            .font(FridjFont.size(15))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
    }

    private var cookButton: some View {
        Button {
            Task { await cook() }
        } label: {
            HStack {
                if isCooking { ProgressView().tint(.white) }
                Text(isCooking ? "Cooking up ideas…" : "Get 3 dinners")
                    .font(FridjFont.size(17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(checked.isEmpty ? Color.fridjText.opacity(0.3) : Color.fridjGreen,
                        in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous))
        }
        .disabled(checked.isEmpty || isCooking)
    }

    // MARK: actions

    private func loadAndScan(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorText = nil
        items = []; checked = []
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else {
                errorText = "Couldn't load that photo."
                return
            }
            pickedImage = img
            isScanning = true
            let detected = try await FrijAPI.scan(image: img)
            items = detected
            // pre-check only the high-confidence ones
            checked = Set(detected.filter { $0.confidence == .high }.map { $0.item })
        } catch {
            errorText = error.localizedDescription
        }
        isScanning = false
    }

    private func cook() async {
        errorText = nil
        isCooking = true
        do {
            let chosen = items.map(\.item).filter { checked.contains($0) }
            recipes = try await FrijAPI.recipes(ingredients: chosen, diet: diet)
            showRecipes = true
        } catch {
            errorText = error.localizedDescription
        }
        isCooking = false
    }
}

// Wrapping chips with a checked state + confidence dot.
struct FlowChips: View {
    let items: [DetectedItem]
    @Binding var checked: Set<String>

    var body: some View {
        // Simple wrapping layout using a LazyVGrid of adaptive width.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                let isOn = checked.contains(item.item)
                Button {
                    if isOn { checked.remove(item.item) } else { checked.insert(item.item) }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(dotColor(item.confidence))
                            .frame(width: 7, height: 7)
                        Text(item.item)
                            .font(FridjFont.size(14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(isOn ? .white : .fridjText.opacity(0.7))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isOn ? Color.fridjGreen : .white,
                                in: Capsule())
                    .overlay(Capsule().stroke(Color.fridjText.opacity(isOn ? 0 : 0.12), lineWidth: 1))
                }
            }
        }
    }

    private func dotColor(_ c: Confidence) -> Color {
        switch c {
        case .high:   return .fridjGreen
        case .medium: return .fridjOrange
        case .low:    return .fridjCoral
        }
    }
}

#Preview {
    ScanView()
}
