import SwiftUI
import PhotosUI

struct ScanFlowCoordinator: View {
    private enum LocalStage { case entry, scanning }

    @State private var localStage: LocalStage = .entry
    @State private var capturedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var scanError: String?
    @State private var store = PantryStore.shared
    @Bindable private var session = ScanSession.shared

    // Single source of truth for "showing results": the session flag plus a
    // photo to show behind it. There is no separate `.review` stage to desync.
    private var isReviewing: Bool { session.showScanFound && capturedImage != nil }

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────
            if (localStage == .scanning || isReviewing), let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
            } else {
                Color.fridjBg.ignoresSafeArea()
            }

            // ── Overlay ───────────────────────────────────────────────
            if localStage == .scanning {
                ScanningView()
            } else if isReviewing {
                EmptyView() // ExpandableTabBar shows the found panel over the photo
            } else {
                entryView
            }
        }
        .sheet(isPresented: $session.showScanOverview, onDismiss: resetToEntry) {
            OverviewView(onDismiss: { session.showScanOverview = false })
        }
        .sheet(isPresented: $session.showRecipes) {
            RecipesView(recipes: session.recipes)
        }
        .sheet(isPresented: $showCamera) {
            CameraCapture { image in Task { await handleImage(image) } }
        }
        .onChange(of: pickerItem) { _, newValue in
            Task { await handlePhoto(newValue) }
        }
        // When the found panel closes (× tapped, tab switched, or "Get dinners"),
        // clear the local photo + picker so the entry view returns cleanly.
        .onChange(of: session.showScanFound) { _, isShowing in
            if !isShowing && !session.showScanOverview {
                capturedImage = nil
                pickerItem = nil
                localStage = .entry
            }
        }
    }

    // MARK: Entry view

    private var entryView: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: FridjSpacing.lg) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan your kitchen")
                            .font(FridjFont.style(.title, weight: .bold))
                            .foregroundColor(.fridjText)
                        Text("Fridge, pantry, spice rack — snap whatever's got food.")
                            .font(FridjFont.size(14))
                            .foregroundColor(.fridjText.opacity(0.5))
                    }
                    .padding(.top, 60)

                    Button { showCamera = true } label: {
                        Label("Scan with camera", systemImage: "camera.fill")
                            .font(FridjFont.size(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.fridjOrange,
                                        in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous))
                    }

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Pick from library", systemImage: "photo.on.rectangle")
                            .font(FridjFont.size(15, weight: .semibold))
                            .foregroundColor(.fridjText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.fridjText.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: FridjRadius.scanButton, style: .continuous))
                    }

                    if let err = scanError ?? session.cookError {
                        Text(err)
                            .font(FridjFont.size(14))
                            .foregroundColor(.fridjCoral)
                    }

                    if store.items.isEmpty {
                        Text("Snap a photo of your fridge or pantry to get started.")
                            .font(FridjFont.size(13))
                            .foregroundColor(.fridjText.opacity(0.5))
                    } else {
                        pantrySection
                        cookButton
                    }
                }
                .padding(FridjSpacing.lg)
                .padding(.bottom, 120)
            }
        }
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
            Text("Scan a photo to update your pantry.")
                .font(FridjFont.size(13))
                .foregroundColor(.fridjText.opacity(0.5))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(store.items) { item in
                    HStack(spacing: 6) {
                        Text(item.name).font(FridjFont.size(14, weight: .medium)).lineLimit(1)
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { store.remove(id: item.id) }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.fridjText.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color(white: 1), in: Capsule())
                    .overlay(Capsule().stroke(Color.fridjText.opacity(0.12), lineWidth: 1))
                }
            }
        }
    }

    private var cookButton: some View {
        Button { session.cook(ingredients: store.allNames) } label: {
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

    // MARK: Helpers

    private func resetToEntry() {
        session.showScanFound = false
        capturedImage = nil
        pickerItem = nil
        localStage = .entry
    }

    private func handlePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        scanError = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else {
            scanError = "Couldn't load that photo."
            return
        }
        await handleImage(img)
    }

    private func handleImage(_ img: UIImage) async {
        // CRITICAL: fully reset any stale review state from a previous scan
        // BEFORE starting a new one. Without this, showScanFound may still be
        // true from last time, so setting it true again is a no-op and the
        // panel never re-triggers — which is the freeze.
        session.showScanFound = false
        session.showScanOverview = false

        capturedImage = img
        pickerItem = nil
        localStage = .scanning

        do {
            let items = try await FrijAPI.scan(image: img)
            let highConfidence = items.filter { $0.confidence == .high }
            store.mergeScan(highConfidence)
            session.scanDetectedItems = items

            // Leave scanning, raise the found panel. isReviewing becomes true
            // because showScanFound is now true AND capturedImage is set.
            localStage = .entry
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                session.showScanFound = true
            }
        } catch {
            scanError = error.localizedDescription
            localStage = .entry
            capturedImage = nil
            session.showScanFound = false
        }
    }
}

#Preview {
    ScanFlowCoordinator()
}
