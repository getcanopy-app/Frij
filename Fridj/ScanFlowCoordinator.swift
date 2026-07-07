import SwiftUI
import PhotosUI
import Photos
import AVFoundation

// Captures the orange scan button's on-screen frame so the action menu can
// grow out of the exact position the user tapped.
private struct ActionButtonFramePreference: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// Captures the Camera ROW'S exact frame inside the menu — the panel morphs
// FROM this precise rectangle, not the whole menu container.
private struct CameraRowFramePreference: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct ScanFlowCoordinator: View {
    private enum LocalStage { case entry, scanning }

    // Derived from the phase machine: .scanning maps through; entry AND reviewing
    // both map to .entry (reviewing keeps the entry chrome under the found panel).
    // Same values + change pattern as the old stored flag, so the
    // .animation(value: localStage) modifier fires identically.
    private var localStage: LocalStage { flow.phase == .scanning ? .scanning : .entry }
    // True whenever the pill has morphed into a full panel (Camera OR Photos).
    // The SHARED morph geometry — panel height, corner radius, dark fill, shadow,
    // clip, row fades — keys off this so both panels grow out of the pill
    // identically. Only the content overlay differs per panel.
    private var isMorphedToPanel: Bool { showCameraPanel || showPhotosPanel }
    // capturedImage now lives on `flow` (ScanFlowModel) — see flow.capturedImage.
    @State private var pickerItem: PhotosPickerItem?
    @State private var showActionMenu = false
    @State private var showCameraPanel = false
    @State private var showPhotosPicker = false
    @State private var showPhotosPanel = false   // custom in-pill photo grid (mirrors showCameraPanel)
    @State private var photosLoader = RecentPhotosLoader()
    // Separate animatable properties for the panel morph — each gets its own
    // timing curve. Independent = no cross-contamination between fast opacity
    // and slow spring frame animations.
    @State private var panelExpanded = false     // frame/position (slow spring)
    @State private var panelVisible = false      // opacity (fast, cross-fades with the button)
    @State private var panelKeepsPreview = false // controls whether the live preview stays visible during the close morph
    // Gaussian blur that ramps up DURING the morph and back to 0 at the ends.
    // Same trick ChatGPT uses to mask the content swap — the eye can't tell
    // that button-label ≠ camera-preview when both are heavily blurred.
    @State private var contentBlur: CGFloat = 0
    @State private var cameraRowSelected = false
    // ── Rubber-band morph modifiers (Gemini's spec) ──
    // Y-scale distortion — temporary vertical stretch beyond 1.0 that snaps back
    @State private var stretchScale: CGFloat = 1.0
    // Corner radius that DIPS mid-transit (velocity peak) then expands to final
    @State private var dynamicCornerRadius: CGFloat = FridjRadius.scanButton
    // Blur applied only to the Camera row's icon + text during the morph — makes
    // them look "pulled apart" rather than cleanly fading
    @State private var rowContentBlur: CGFloat = 0
    // Time-lockout: after closing the camera panel, ignore tap-outside for a
    // brief moment so the X tap that closed the panel doesn't ALSO close the
    // menu. Otherwise we lose the Photos row.
    @State private var lastCameraCloseAt: Date? = nil
    // Growing photo overlay — permanently mounted (empty UIImage placeholder
    // when idle) so .animation(_:value:) modifiers have a stable view
    // identity across scale changes.
    @State private var expandingImage: UIImage?
    @State private var expansionStartFrame: CGRect = .zero
    @State private var overlayScale: CGFloat = 1.0
    @State private var overlayCornerRadius: CGFloat = 32
    // Handle to the in-flight scan Task so the user can cancel it. Cancelling
    // the Task aborts the URLSession request so the OpenAI API call stops.
    @State private var scanTask: Task<Void, Never>? = nil
    @State private var store = PantryStore.shared
    @Bindable private var session = ScanSession.shared
    @State private var sub = SubscriptionManager.shared
    @State private var usage = UsageStore.shared
    // Explicit, testable phase machine. Currently shadows the @State flags above
    // (its methods are called at each transition below); see ScanFlowModel.swift.
    @State private var flow = ScanFlowModel()
    @State private var cameraController = CameraSessionController()
    @State private var actionButtonFrame: CGRect = .zero
    @State private var cameraRowFrame: CGRect = .zero
    @Namespace private var cameraNamespace

    // Reviewing = found panel up. Photo stays behind it the whole time.
    // Owned by the phase machine now: the only entry is runScan success (which
    // sets phase = .reviewing alongside session.showScanFound = true). External
    // dismissal from ExpandableTabBar flips showScanFound, and the onChange below
    // funnels that into flow.reset() so the phase leaves reviewing in lockstep.
    private var isReviewing: Bool { flow.phase == .reviewing }

    // Show the fridge photo during scanning AND review. Keeping this as one
    // condition (not a stored stage) means the photo never flickers off
    // between scan-complete and panel-appear.
    private var showPhotoBackground: Bool {
        (localStage == .scanning || isReviewing) && flow.capturedImage != nil
    }

    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()

            // Opaque dark backing whenever a photo has been captured — this
            // prevents Color.fridjBg (cream) from leaking through the
            // semi-transparent layers during the entryView/bgPhoto crossfade.
            if flow.capturedImage != nil {
                Color.fridjDark.ignoresSafeArea()
            }

            if showPhotoBackground, let img = flow.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.2).ignoresSafeArea())
                    .transition(.opacity)
            }

            if localStage == .scanning {
                ScanningView(onCancel: { cancelScan() })
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if isReviewing {
                EmptyView()
            } else {
                entryView
                    .transition(.opacity)
            }

            // Growing-photo overlay — permanently mounted (empty UIImage
            // placeholder when idle) so .animation(_:value:) modifiers have
            // a stable view identity across scale changes. Visibility via
            // opacity, not conditional insertion.
            ZStack {
                let framePresent = expansionStartFrame.width > 0 && expansionStartFrame.height > 0
                Image(uiImage: expandingImage ?? UIImage())
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: framePresent ? expansionStartFrame.width : 1,
                        height: framePresent ? expansionStartFrame.height : 1
                    )
                    .clipShape(RoundedRectangle(
                        cornerRadius: overlayCornerRadius,
                        style: .continuous
                    ))
                    .scaleEffect(overlayScale, anchor: .center)
                    .animation(.easeInOut(duration: 1.5), value: overlayScale)
                    .animation(.easeInOut(duration: 1.5), value: overlayCornerRadius)
                    .position(
                        x: framePresent ? expansionStartFrame.midX : 0,
                        y: framePresent ? expansionStartFrame.midY : 0
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(expandingImage != nil ? 1 : 0)
            .zIndex(50)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.75), value: showPhotoBackground)
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: localStage)
        .sheet(isPresented: $session.showScanOverview, onDismiss: resetToEntry) {
            OverviewView(onDismiss: { session.showScanOverview = false })
        }
        .sheet(isPresented: $session.showRecipes) {
            RecipesView()
        }
        .photosPicker(isPresented: $showPhotosPicker,
                      selection: $pickerItem,
                      matching: .images)
        .onPreferenceChange(ActionButtonFramePreference.self) { frame in
            if frame != .zero { actionButtonFrame = frame }
        }
        .onPreferenceChange(CameraRowFramePreference.self) { frame in
            if frame != .zero { cameraRowFrame = frame }
        }
        .onChange(of: pickerItem) { _, newValue in
            Task { await handlePhoto(newValue) }
        }
        .onChange(of: session.showScanFound) { _, isShowing in
            if !isShowing && !session.showScanOverview {
                // Found panel dismissed (often externally, from ExpandableTabBar) —
                // leave the reviewing phase. The photo then fades out via the
                // .animation(value: showPhotoBackground) modifier; clear it after.
                flow.reset()
                Task {
                    try? await Task.sleep(nanoseconds: 360_000_000)
                    await MainActor.run {
                        // Only clear if still not reviewing AND not mid-scan —
                        // without the localStage guard, a new scan started while
                        // the found panel was visible would have its photo cleared
                        // after the 360ms window while showScanFound is still false.
                        if !session.showScanFound && localStage != .scanning {
                            flow.capturedImage = nil
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

                    // In-place morph: ONE view slot whose content (button label ↔
                    // menu rows) cross-fades and whose background rounded rect
                    // grows and shifts color from orange → white. The container's
                    // height changes with its content, so the shape physically
                    // grows out of the button — no swipe, no separate popup.
                    // The opacity animation for showCameraPanel is decoupled from
                    // the outer withAnimation so we can DELAY the fade-in on close
                    // — otherwise the button pops back into view while the panel
                    // is still shrinking.
                    // NO matched geometry on the button — that's what was
                    // making it "swipe up" from the panel's frame during close.
                    // Button stays put; the panel morphs to/from its position.
                    // Button stays fully visible throughout — the camera panel
                    // just covers it when open. No opacity fade = no "cheap"
                    // cross-fade feel. Blur ramps identically so button + panel
                    // read as one fuzzy shape morphing.
                    morphingScanButton
                        .zIndex(showActionMenu ? 10 : 0)

                    if let err = flow.lastError ?? session.cookError {
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
        // Tap-outside-to-close via .onTapGesture on the outer ZStack. Unlike
        // simultaneousGesture, this respects child buttons' tap priority —
        // if you tap a Button (orange scan, Camera row, Photos row, pantry
        // items, etc.), that button's action fires and this gesture does NOT.
        // Only fires when the tap lands on non-interactive background.
        .onTapGesture(coordinateSpace: .global) { location in
            guard showActionMenu, !showCameraPanel, !showPhotosPanel, !showPhotosPicker else { return }
            // Ignore taps for a moment after the camera panel closes — the tap
            // that dismissed it should NOT also close the menu.
            if let closedAt = lastCameraCloseAt, Date().timeIntervalSince(closedAt) < 0.6 {
                return
            }
            let inMenu = actionButtonFrame.contains(location)
            let inRow  = cameraRowFrame.contains(location)
            if !inMenu && !inRow {
                withAnimation(.spring(duration: 0.42, bounce: 0.15)) {
                    showActionMenu = false
                }
            }
        }
    }

    // MARK: Morphing scan button (button ↔ menu, same shape, in place)

    // Panel height when fully expanded. The morphing pill grows to THIS height
    // when the camera panel is open — same view, same identity, just larger.
    private var expandedPanelHeight: CGFloat { 520 }

    @ViewBuilder
    private var morphingScanButton: some View {
        ZStack {
            // Content layer — cross-fades between button label and menu rows.
            Group {
                if showActionMenu {
                    VStack(spacing: 0) {
                        morphRow(icon: "camera.fill", title: "Camera",
                                 tint: .fridjOrange, foreground: .fridjText,
                                 action: openCameraFromMenu)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(key: CameraRowFramePreference.self,
                                                           value: geo.frame(in: .global))
                                }
                            )
                            .opacity(isMorphedToPanel ? 0 : 1)
                            .scaleEffect(isMorphedToPanel ? 0.95 : 1.0)
                        // Divider + Photos row are ALWAYS mounted. Their frame
                        // and opacity are tied to the panel morph (isMorphedToPanel)
                        // so they interpolate smoothly along the same spring —
                        // never binary appear/disappear.
                        // Concrete collapsed/expanded heights (NOT nil) so the
                        // row interpolates continuously along the close spring.
                        // Animating a frame height to `nil` can't interpolate —
                        // it holds at 0 and snaps open only when the spring ends,
                        // which is what made the Photos row "blink back" on close.
                        Divider().overlay(Color.fridjText.opacity(0.08))
                            .opacity(isMorphedToPanel ? 0 : 1)
                        morphRow(icon: "photo.on.rectangle", title: "Photos",
                                 tint: .fridjOrange, foreground: .fridjText,
                                 action: openPhotosFromMenu)
                            .opacity(isMorphedToPanel ? 0 : 1)
                            .scaleEffect(isMorphedToPanel ? 0.95 : 1.0)
                            .clipped()
                    }
                    .transition(.opacity)
                } else {
                    Button { openActionMenu() } label: {
                        Label("Scan with camera", systemImage: "camera.fill")
                            .font(FridjFont.size(16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
        // THIS is the morph: same view, same shape identity, changes SIZE.
        // Pill height when menu is open, panel height when expanded, button
        // height otherwise. Corner radius transitions from pill to panel radius.
        .frame(height: isMorphedToPanel ? expandedPanelHeight : nil)
        // Camera preview + controls live OVER the pill's own background — so
        // it's literally the SAME shape hosting different content depending on
        // state. When collapsed, the overlay is invisible (opacity 0).
        .overlay {
            embeddedCameraPanel
                .opacity(showCameraPanel ? 1 : 0)
                .allowsHitTesting(showCameraPanel)
        }
        // Photos grid — same pill, same shape, different content. Mirrors the
        // camera overlay exactly; only one of the two is ever visible at a time.
        .overlay {
            embeddedPhotosPanel
                .opacity(showPhotosPanel ? 1 : 0)
                .allowsHitTesting(showPhotosPanel)
        }

        .background(
            RoundedRectangle(cornerRadius: isMorphedToPanel ? 32 : FridjRadius.scanButton,
                             style: .continuous)
                .fill(isMorphedToPanel ? Color.fridjDark : (showActionMenu ? Color.white : Color.fridjOrange))
        )
        .overlay(
            RoundedRectangle(cornerRadius: isMorphedToPanel ? 32 : FridjRadius.scanButton,
                             style: .continuous)
                .stroke(Color.fridjText.opacity(showActionMenu && !isMorphedToPanel ? 0.06 : 0),
                        lineWidth: 1)
        )
        .shadow(color: .black.opacity((showActionMenu || isMorphedToPanel) ? 0.15 : 0),
                radius: (showActionMenu || isMorphedToPanel) ? 22 : 0,
                y: (showActionMenu || isMorphedToPanel) ? 10 : 0)
        .clipShape(RoundedRectangle(cornerRadius: isMorphedToPanel ? 32 : FridjRadius.scanButton,
                                    style: .continuous))
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ActionButtonFramePreference.self,
                                       value: geo.frame(in: .global))
            }
        )
    }

    // The camera preview + controls, embedded INSIDE the morphing pill's own
    // shape. Uses the same session controller so warming still works.
    @ViewBuilder
    private var embeddedCameraPanel: some View {
        CameraPanel(
            controller: cameraController,
            cornerRadius: 32,
            isActive: panelKeepsPreview,
            onCapture: { img in handleCameraCapture(img) },
            onDismiss: { closeCameraPanel() },
            onPickLibrary: { openPhotosFromCameraPanel() }
        )
    }

    // The photos grid, embedded INSIDE the morphing pill's shape — the Photos
    // parallel to embeddedCameraPanel. A scrollable grid of the user's recent
    // photos, with a "See all" fallback to the system picker and a graceful
    // access-denied prompt. Tapping a thumbnail is wired into the scan flow in
    // the next step.
    @ViewBuilder
    private var embeddedPhotosPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Text("Photos")
                    .font(FridjFont.size(16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if photosLoader.authorization == .authorized || photosLoader.authorization == .limited {
                    // Fall back to Apple's full library picker for older photos.
                    Button { openSystemPickerFromPanel() } label: {
                        Text("See all")
                            .font(FridjFont.size(14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }
                Button { closePhotosPanel() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(10)
                        .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            switch photosLoader.authorization {
            case .authorized, .limited:
                photosGrid
            case .denied, .restricted:
                photosAccessDenied
            default:
                // .notDetermined — the permission request kicked off on open is
                // still in flight; leave the panel empty until it resolves.
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var photosGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
                      spacing: 6) {
                ForEach(photosLoader.assets, id: \.localIdentifier) { asset in
                    PhotoThumbCell(asset: asset, loader: photosLoader, onTap: {})
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private var photosAccessDenied: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "lock.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white.opacity(0.7))
            Text("Photo access is off")
                .font(FridjFont.size(16, weight: .bold))
                .foregroundColor(.white)
            Text("Turn on photo access so Frij can pull in a fridge photo from your library.")
                .font(FridjFont.size(13))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button { openAppSettings() } label: {
                Text("Open Settings")
                    .font(FridjFont.size(15, weight: .bold))
                    .foregroundColor(.fridjDark)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func morphRow(icon: String, title: String,
                          tint: Color, foreground: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(FridjFont.size(16, weight: .semibold))
                    .foregroundColor(foreground)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
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

    // MARK: Action menu

    private func openActionMenu() {
        flow.lastError = nil
        // Pre-warm the capture session the moment the menu opens. By the time
        // the user picks Camera (a few 100ms later at best), the AVCaptureSession
        // is already running and producing frames — the preview shows up
        // essentially instantly on tap.
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            cameraController.start()
        }
        withAnimation(.smooth(duration: 0.35, extraBounce: 0)) {
            showActionMenu = true
        }
    }

    private func closeActionMenu() {
        withAnimation(.smooth(duration: 0.32, extraBounce: 0)) {
            showActionMenu = false
        }
        // User dismissed the menu without picking Camera — stop the warm-up
        // to save battery.
        cameraController.stop()
    }

    private func openCameraFromMenu() {
        cameraController.start()
        panelKeepsPreview = true

        // The pill IS the panel. Toggling showCameraPanel drives everything:
        // the pill's height grows to expandedPanelHeight, the background color
        // transitions, corners round out, embedded camera content fades in.
        // ALL animated via ONE unified spring.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
            showCameraPanel = true
            session.hidesTabBar = true
        }
    }

    private func openPhotosFromMenu() {
        // The pill IS the panel — mirror openCameraFromMenu exactly, just toggling
        // showPhotosPanel instead. The SAME unified spring drives the height grow,
        // corner round, dark fill, and the embedded photos content fading in.
        cameraController.stop()
        // Request access (once) + fetch recents as the panel grows in.
        Task { await photosLoader.loadIfNeeded() }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
            showPhotosPanel = true
            session.hidesTabBar = true
        }
    }

    private func closePhotosPanel() {
        // Reuse the camera panel's tap-lockout so the X tap that closes this panel
        // doesn't ALSO trip tap-outside-to-close on the menu behind it.
        lastCameraCloseAt = Date()
        // Same unified spring in reverse — pill shrinks from panel-size back to its
        // natural pill dimensions. No camera session to tear down here.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
            showPhotosPanel = false
            session.hidesTabBar = false
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func openSystemPickerFromPanel() {
        // "See all" — hand off to Apple's full library picker (the long tail of
        // older photos), then collapse the in-pill panel behind the sheet.
        showPhotosPicker = true
        closePhotosPanel()
    }

    // MARK: Camera panel

    private func openCameraPanel() {
        flow.lastError = nil
        cameraController.start()
        showCameraPanel = true
        panelKeepsPreview = true
        panelVisible = true
        withAnimation(.easeIn(duration: 0.1)) { contentBlur = 14 }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.74, blendDuration: 0)) { panelExpanded = true }
        withAnimation(.easeOut(duration: 0.25).delay(0.32)) { contentBlur = 0 }
    }

    private func closeCameraPanel() {
        lastCameraCloseAt = Date()
        // Same unified spring in reverse — pill shrinks from panel-size back
        // to its natural pill dimensions, content transitions back.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
            showCameraPanel = false
            session.hidesTabBar = false
        }
        // Kill the camera session after the spring settles — but ONLY if the
        // panel wasn't reopened in the meantime. Without this guard, a quick
        // close→reopen tears the reopened panel back down at T+0.6s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard !showCameraPanel else { return }
            panelKeepsPreview = false
            cameraController.stop()
        }
    }

    private func openPhotosFromCameraPanel() {
        showPhotosPicker = true
        lastCameraCloseAt = Date()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0)) {
            showCameraPanel = false
            session.hidesTabBar = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard !showCameraPanel else { return }
            panelKeepsPreview = false
            cameraController.stop()
        }
    }

    private func handleCameraCapture(_ img: UIImage) {
        let displayImage = ImagePrep.downscale(img, maxEdge: 1200)

        session.showScanFound = false
        session.showScanOverview = false
        pickerItem = nil

        // Compute target scale from panel frame
        let start = actionButtonFrame
        let screen = UIScreen.main.bounds
        let sX = 2 * max(start.midX, screen.width  - start.midX) / start.width
        let sY = 2 * max(start.midY, screen.height - start.midY) / start.height
        let targetScale = max(sX, sY) * 1.05

        // Seed overlay at scale 1.0
        overlayScale = 1.0
        overlayCornerRadius = 32
        expansionStartFrame = start
        expandingImage = displayImage

        // After 200ms, trigger the scale animation via .animation(_:value:)
        // modifiers on the Image
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            overlayScale = targetScale
            overlayCornerRadius = 0
            withAnimation(.easeInOut(duration: 1.5)) {
                session.hidesTabBar = true
            }
        }

        // After zoom settles, commit to scanning stage
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            flow.capturedImage = displayImage
            showCameraPanel = false
            showActionMenu = false
            panelKeepsPreview = false
            cameraController.stop()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82, blendDuration: 0)) {
                flow.beginScan()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                overlayScale = 1.0
                overlayCornerRadius = 32
                expandingImage = nil
            }
        }

        Task.detached {
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            }
        }
        scanTask?.cancel()
        scanTask = Task { await runScan(displayImage) }
    }

    // Called from the Cancel button in ScanningView. Cancels the URLSession
    // request in flight and returns the UI to the entry state — no API charge.
    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            flow.cancel()
            flow.capturedImage = nil
            session.hidesTabBar = false
        }
        overlayScale = 1.0
        overlayCornerRadius = 32
        expandingImage = nil
        session.showScanFound = false
        session.scanDetectedItems = []
    }

    // Runs the FrijAPI scan on a photo whose display state is ALREADY on screen
    // (i.e. capturedImage set, localStage = .scanning). Separates the "what
    // happens on screen right now" from "network work happening in background".
    private func runScan(_ displayImage: UIImage) async {
        do {
            let items = try await FrijAPI.scan(image: displayImage)
            if Task.isCancelled { return }
            await MainActor.run {
                // Re-check on the MainActor: the guard above ran OFF the actor, so
                // a cancel (cancelScan) can land in the window between it and this
                // block. Without this, a scan cancelled mid-apply would still
                // merge + flip to reviewing — resurrecting a cancelled scan.
                if Task.isCancelled { return }
                let highConfidence = items.filter { $0.confidence == .high }
                store.mergeScan(highConfidence)
                session.scanDetectedItems = items

                // Bring the tab bar back FIRST (its own animation), then
                // transition to review state.
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    session.hidesTabBar = false
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    flow.scanSucceeded(items)
                    session.showScanFound = true
                }
            }
        } catch {
            if Task.isCancelled { return }
            if (error as NSError).code == NSURLErrorCancelled { return }
            await MainActor.run {
                flow.scanFailed(error.localizedDescription)
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    session.hidesTabBar = false
                }
                // flow.scanFailed above already moved phase → .entry (the
                // localStage modifier animates that); this block just fades the photo.
                withAnimation(.easeInOut(duration: 0.35)) {
                    flow.capturedImage = nil
                }
                session.showScanFound = false
            }
        }
    }

    // MARK: Helpers

    private func resetToEntry() {
        session.showScanFound = false
        flow.capturedImage = nil
        pickerItem = nil
        flow.reset()
        overlayScale = 1.0
        overlayCornerRadius = 32
        expandingImage = nil
        session.hidesTabBar = false
    }

    private func handlePhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        flow.lastError = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else {
            flow.lastError = "Couldn't load that photo."
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

        // Hide the tab bar during analysis so the user can't navigate away
        // mid-scan — matches the camera path (handleCameraCapture). Restore is
        // shared: runScan (success/error) and cancelScan all set it back to false.
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            flow.capturedImage = displayImage
            session.hidesTabBar = true
            flow.beginScan()
        }
        pickerItem = nil

        // Store the scan task so the Cancel button can abort it.
        scanTask?.cancel()
        scanTask = Task { await runScan(displayImage) }
    }
}

#Preview {
    ScanFlowCoordinator()
}

// Loads the user's most-recent photos for the in-pill grid. Owns a
// PHCachingImageManager and the PHAsset fetch so ALL Photos-framework calls stay
// out of the View. @MainActor so its @Observable state publishes safely.
@MainActor
@Observable
final class RecentPhotosLoader {
    private(set) var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private(set) var assets: [PHAsset] = []

    private let imageManager = PHCachingImageManager()

    // Ensure access (requesting once if undetermined), then fetch recents. On
    // denied/restricted this just publishes the status so the View can prompt.
    func loadIfNeeded(limit: Int = 60) async {
        var status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        authorization = status
        guard status == .authorized || status == .limited else {
            assets = []
            return
        }
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.fetchLimit = limit
        let result = PHAsset.fetchAssets(with: options)
        var collected: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in collected.append(asset) }
        assets = collected
    }

    // One-shot thumbnail for a cell. highQualityFormat delivers a SINGLE result
    // callback, so the continuation is resumed exactly once.
    func thumbnail(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            imageManager.requestImage(for: asset,
                                      targetSize: targetSize,
                                      contentMode: .aspectFill,
                                      options: options) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// One square thumbnail in the grid. Loads its image when it appears; `onTap` is
// a no-op until selection is wired into the scan flow.
private struct PhotoThumbCell: View {
    let asset: PHAsset
    let loader: RecentPhotosLoader
    let onTap: () -> Void
    @State private var image: UIImage?

    var body: some View {
        Button(action: onTap) {
            Color.white.opacity(0.06)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .task(id: asset.localIdentifier) {
            let px = 120 * UIScreen.main.scale
            image = await loader.thumbnail(for: asset,
                                           targetSize: CGSize(width: px, height: px))
        }
    }
}
