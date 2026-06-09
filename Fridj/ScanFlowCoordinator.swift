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
                GeometryReader { geo in
                    ForEach(Array(session.scanDetectedItems.enumerated()), id: \.element.id) { index, item in
                        detectionLabel(item.item)
                            .position(labelPosition(for: item, index: index, in: geo.size))
                            .transition(.opacity.combined(with: .scale(scale: 0.7)))
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.06),
                                value: isReviewing
                            )
                    }
                }
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
        .sheet(isPresented: $showCamera) {
            CameraCapture { image in Task { await handleImage(image) } }
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
                        // Only clear if we're still not reviewing (user didn't
                        // immediately start another scan).
                        if !session.showScanFound {
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

    // MARK: Detection labels

    // Fallback scattered positions for items the model couldn't place.
    private static let labelPositions: [(CGFloat, CGFloat)] = [
        (0.65, 0.18), (0.22, 0.38), (0.58, 0.52), (0.32, 0.16),
        (0.72, 0.40), (0.18, 0.55), (0.48, 0.28), (0.38, 0.62),
        (0.60, 0.08), (0.28, 0.72), (0.75, 0.60), (0.15, 0.22),
    ]

    private func labelPosition(for item: DetectedItem, index: Int, in size: CGSize) -> CGPoint {
        // DEBUG: print the raw box so we can judge gpt-4o's accuracy.
        if let b = item.box {
            print("📦 \(item.item): x=\(String(format: "%.2f", b.x)) y=\(String(format: "%.2f", b.y)) w=\(String(format: "%.2f", b.w)) h=\(String(format: "%.2f", b.h)) → center(\(String(format: "%.2f", b.centerX)), \(String(format: "%.2f", b.centerY)))")
        } else {
            print("📦 \(item.item): NO BOX (using fallback position)")
        }

        // If the model gave us a box, place the dot at its center, scaled to the
        // actual on-screen photo size. The photo uses .scaledToFill in a
        // full-screen frame, so fractions map directly to screen width/height.
        if let b = item.box {
            let x = b.centerX * size.width
            let y = b.centerY * size.height
            // Clamp so labels never sit under the found panel or off-screen.
            let clampedX = min(max(x, 60), size.width - 60)
            let clampedY = min(max(y, 70), size.height - 280)
            return CGPoint(x: clampedX, y: clampedY)
        }

        // Fallback: scattered position for items with no box.
        let topInset: CGFloat = 70
        let bottomInset: CGFloat = 260
        let sidePadding: CGFloat = 50
        let usableW = size.width - sidePadding * 2
        let usableH = size.height - topInset - bottomInset
        let (xRatio, yRatio) = Self.labelPositions[index % Self.labelPositions.count]
        return CGPoint(x: sidePadding + xRatio * usableW, y: topInset + yRatio * usableH)
    }

    private func detectionLabel(_ name: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
            Text(name.capitalized)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.08))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
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
        // Always start from a clean slate so showScanFound flips false→true
        // (a no-op true→true would never re-trigger the panel).
        session.showScanFound = false
        session.showScanOverview = false

        withAnimation(.easeInOut(duration: 0.35)) {
            capturedImage = img
            localStage = .scanning
        }
        pickerItem = nil

        do {
            let items = try await FrijAPI.scan(image: img)
            let highConfidence = items.filter { $0.confidence == .high }
            store.mergeScan(highConfidence)
            session.scanDetectedItems = items

            // Photo STAYS up (capturedImage is still set, isReviewing becomes
            // true). Only the scanning overlay goes away and the panel rises.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                localStage = .entry        // leaves the scanning overlay
                session.showScanFound = true  // raises the found panel; photo stays
            }
        } catch {
            scanError = error.localizedDescription
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
