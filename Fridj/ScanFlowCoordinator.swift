import SwiftUI
import PhotosUI
import Photos

struct ScanFlowCoordinator: View {
    private enum LocalStage { case entry, scanning }

    @State private var localStage: LocalStage = .entry
    @State private var capturedImage: UIImage?
    @State private var pendingImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var scanError: String?
    @State private var store = PantryStore.shared
    @Bindable private var session = ScanSession.shared
    @State private var sub = SubscriptionManager.shared
    @State private var usage = UsageStore.shared

    // Reviewing = found panel up. Photo stays behind it the whole time.
    private var isReviewing: Bool { session.showScanFound && capturedImage != nil }

    // Show the fridge photo during scanning AND review. Keeping this as one
    // condition (not a stored stage) means the photo never flickers off
    // between scan-complete and panel-appear.
    private var showPhotoBackground: Bool {
        (localStage == .scanning || isReviewing) && capturedImage != nil
    }

    var body: some View {
        ZStack {
            // ── Background ────────────────────────────────────────────
            // Cream base is always there; the photo crossfades in over it.
            Color.fridjBg.ignoresSafeArea()

            if showPhotoBackground, let img = capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.2).ignoresSafeArea())
                    .transition(.opacity)  // smooth fade in/out of the photo
            }

            // ── Overlay ───────────────────────────────────────────────
            if localStage == .scanning {
                ScanningView()
                    .transition(.opacity)
            } else if isReviewing {
                EmptyView()
            } else {
                entryView
                    .transition(.opacity)
            }
        }
        // Animate background + overlay swaps so the photo→panel change is smooth.
        .animation(.easeInOut(duration: 0.35), value: showPhotoBackground)
        .animation(.easeInOut(duration: 0.35), value: localStage)
        .sheet(isPresented: $session.showScanOverview, onDismiss: resetToEntry) {
            OverviewView(onDismiss: { session.showScanOverview = false })
        }
        .sheet(isPresented: $session.showRecipes) {
            RecipesView()
        }
        .sheet(isPresented: $showCamera, onDismiss: {
            guard let img = pendingImage else { return }
            pendingImage = nil
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                capturedImage = img
                if !session.showScanFound { localStage = .scanning }
            }
        }) {
            CameraCapture(
                onCapture: { image in Task { await handleImage(image, saveToLibrary: true) } },
                onDismiss: { showCamera = false }
            )
        }
        .onChange(of: pickerItem) { _, newValue in
            Task { await handlePhoto(newValue) }
        }
        .onChange(of: session.showScanFound) { _, isShowing in
            if !isShowing && !session.showScanOverview {
                // Fade the photo out smoothly, then clear it after the fade.
                withAnimation(.easeInOut(duration: 0.35)) {
                    localStage = .entry
                }
                Task {
                    try? await Task.sleep(nanoseconds: 360_000_000)
                    await MainActor.run {
                        // Only clear if still not reviewing AND not mid-scan —
                        // without the localStage guard, a new scan started while
                        // the found panel was visible would have its photo cleared
                        // after the 360ms window while showScanFound is still false.
                        if !session.showScanFound && localStage != .scanning {
                            capturedImage = nil
                            pickerItem = nil
                        }
                    }
                }
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
        VStack(spacing: 8) {
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

            if !sub.isSubscribed && !store.items.isEmpty {
                freeUsageHint
            }
        }
    }

    @ViewBuilder
    private var freeUsageHint: some View {
        if session.isPremiumGated {
            Button { sub.showPaywall = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Unlock unlimited with Frij+")
                        .font(FridjFont.size(12, weight: .bold))
                }
                .foregroundColor(.fridjOrange)
            }
        } else if usage.remaining <= UsageStore.freeLimit {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.fridjOrange)
                Text("\(usage.remaining) free idea\(usage.remaining == 1 ? "" : "s") remaining")
                    .font(FridjFont.size(12))
                    .foregroundColor(.fridjText.opacity(0.45))
            }
        }
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

    private func handleImage(_ img: UIImage, saveToLibrary: Bool = false) async {
        if saveToLibrary {
            try? await PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            })
        }
        // Downscale for display/scan — original full-res ref is no longer needed after library save.
        let displayImage = ImagePrep.downscale(img, maxEdge: 1200)

        session.showScanFound = false
        session.showScanOverview = false

        if showCamera {
            // Camera path: stash the photo and close the sheet.
            // The sheet's onDismiss springs the photo into view once the
            // UIKit sheet animation finishes — no jarring cut.
            pendingImage = displayImage
            showCamera = false
        } else {
            // Photo picker path: no sheet to dismiss, animate directly.
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                capturedImage = displayImage
                localStage = .scanning
            }
        }
        pickerItem = nil

        do {
            let items = try await FrijAPI.scan(image: displayImage)
            let highConfidence = items.filter { $0.confidence == .high }
            store.mergeScan(highConfidence)
            session.scanDetectedItems = items

            // Safety: if onDismiss hasn't fired yet, set the photo now.
            if capturedImage == nil {
                capturedImage = pendingImage ?? displayImage
                pendingImage = nil
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                localStage = .entry
                session.showScanFound = true
            }
        } catch {
            scanError = error.localizedDescription
            pendingImage = nil
            withAnimation(.easeInOut(duration: 0.35)) {
                localStage = .entry
                capturedImage = nil
            }
            session.showScanFound = false
        }
    }
}

#Preview {
    ScanFlowCoordinator()
}
