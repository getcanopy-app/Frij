import SwiftUI
import PhotosUI

struct ScanView: View {
    @State private var store = PantryStore.shared

    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?

    @State private var detected: [DetectedItem] = []
    @State private var newlyAddedNames: Set<String> = []

    @Bindable private var session = ScanSession.shared

    @State private var newItem: String = ""
    @State private var isScanning = false
    @State private var isValidating = false
    @State private var errorText: String?
    @State private var rejectionText: String?

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
                        Label(pickedImage == nil ? "Pick a photo" : "Pick a different photo",
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
                            Text("Reading your kitchen…")
                                .font(FridjFont.size(14))
                                .foregroundColor(.fridjText.opacity(0.6))
                        }
                    }

                    if let err = errorText ?? session.cookError {
                        Text(err)
                            .font(FridjFont.size(14))
                            .foregroundColor(.fridjCoral)
                    }

                    if !detected.isEmpty {
                        detectedSection
                    }

                    if !store.items.isEmpty {
                        pantrySection
                        addRow
                        if let rejectionText {
                            Text(rejectionText)
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjCoral)
                        }
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
        .sheet(isPresented: $session.showRecipes) {
            RecipesView(recipes: session.recipes)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Scan your kitchen")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Fridge, pantry, spice rack — snap whatever's got food.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.5))
        }
        .padding(.top, 60)
    }

    private var detectedSection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            Text("Just spotted")
                .font(FridjFont.size(18, weight: .bold))
                .foregroundColor(.fridjText)

            HStack(spacing: 14) {
                Text("\(newlyAddedNames.count) new")
                    .font(FridjFont.size(12, weight: .bold))
                    .foregroundColor(.fridjGreen)
                Text("\(detected.count - newlyAddedNames.count) already in pantry")
                    .font(FridjFont.size(12, weight: .medium))
                    .foregroundColor(.fridjText.opacity(0.5))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                      alignment: .leading, spacing: 8) {
                ForEach(detected) { item in
                    chip(for: item)
                }
            }
        }
    }

    private func chip(for item: DetectedItem) -> some View {
        let isNew = newlyAddedNames.contains(item.item)
        return HStack(spacing: 6) {
            Circle().fill(dotColor(item.confidence)).frame(width: 7, height: 7)
            Text(item.item).font(FridjFont.size(14, weight: .medium)).lineLimit(1)
        }
        .foregroundColor(isNew ? .white : .fridjText.opacity(0.7))
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(isNew ? Color.fridjGreen : .white, in: Capsule())
        .overlay(Capsule().stroke(Color.fridjText.opacity(isNew ? 0 : 0.12), lineWidth: 1))
    }

    private var pantrySection: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("In your pantry")
                    .font(FridjFont.size(18, weight: .bold))
                    .foregroundColor(.fridjText)
                Spacer()
                Text("\(store.items.count)")
                    .font(FridjFont.size(14, weight: .bold))
                    .foregroundColor(.fridjText.opacity(0.4))
            }
            Text("Tap × to remove anything that's not actually there.")
                .font(FridjFont.size(13))
                .foregroundColor(.fridjText.opacity(0.5))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                      alignment: .leading, spacing: 8) {
                ForEach(store.items) { item in
                    HStack(spacing: 6) {
                        Text(item.name).font(FridjFont.size(14, weight: .medium)).lineLimit(1)
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) {
                                store.remove(id: item.id)
                                newlyAddedNames.remove(item.name)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.fridjText.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().stroke(Color.fridjText.opacity(0.12), lineWidth: 1))
                }
            }
        }
    }

    private var addRow: some View {
        HStack {
            TextField("add something we missed", text: $newItem)
                .font(FridjFont.size(15))
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous))
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

    private var cookButton: some View {
        Button {
            session.cook(ingredients: store.allNames)
        } label: {
            HStack {
                if session.isCooking { ProgressView().tint(.white) }
                Text(session.isCooking ? "Cooking up ideas…" : "Get 3 dinners")
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

    private func loadAndScan(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorText = nil
        detected = []
        newlyAddedNames = []
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let img = UIImage(data: data) else {
                errorText = "Couldn't load that photo."
                return
            }
            pickedImage = img
            isScanning = true
            let items = try await FrijAPI.scan(image: img)
            detected = items
            let highConfidence = items.filter { $0.confidence == .high }
            let added = store.mergeScan(highConfidence)
            newlyAddedNames = Set(added)
        } catch {
            errorText = error.localizedDescription
        }
        isScanning = false
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

    private func dotColor(_ c: Confidence) -> Color {
        switch c {
        case .high: return .fridjGreen
        case .medium: return .fridjOrange
        case .low: return .fridjCoral
        }
    }
}

#Preview {
    ScanView()
}
