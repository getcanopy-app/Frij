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

    @State private var localStage: LocalStage = .entry
    @State private var capturedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showActionMenu = false
    @State private var showCameraPanel = false
    @State private var showPhotosPicker = false
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
    // Growing photo overlay: an Image placed at the panel's exact captured
    // frame and scaled up in place around its own center.
    @State private var expandingImage: UIImage?
    @State private var expansionActive: Bool = false
    @State private var expansionStartFrame: CGRect = .zero
    // Handle to the in-flight scan Task so the user can cancel it. Cancelling
    // the Task aborts the URLSession request so the OpenAI API call stops.
    @State private var scanTask: Task<Void, Never>? = nil
    @State private var scanError: String?
    @State private var store = PantryStore.shared
    @Bindable private var session = ScanSession.shared
    @State private var sub = SubscriptionManager.shared
    @State private var usage = UsageStore.shared
    @State private var cameraController = CameraSessionController()
    @State private var actionButtonFrame: CGRect = .zero
    @State private var cameraRowFrame: CGRect = .zero
    @Namespace private var cameraNamespace

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
                    .transition(.opacity)
            }

            // ── Overlay ───────────────────────────────────────────────
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

            // Camera panel is now EMBEDDED inside morphingScanButton itself
            // (in entryView). The pill IS the panel — one view, one shape,
            // grows and shrinks. No separate overlay needed.

            // Growing-photo overlay — the frozen still, scaled up IN PLACE
            // around its own center. Only .scaleEffect animates; padding is a
            // static placement that never moves. Animation is kicked off from
            // .onAppear so the first render is guaranteed to happen at scale
            // 1.0 BEFORE we flip expansionActive — otherwise SwiftUI batches
            // the two state changes and skips straight to the final state,
            // making the zoom look like a snap.
            if let img = expandingImage {
                let start = expansionStartFrame
                let screen = UIScreen.main.bounds
                let scaleX = 2 * max(start.midX, screen.width  - start.midX) / start.width
                let scaleY = 2 * max(start.midY, screen.height - start.midY) / start.height
                let targetScale = max(scaleX, scaleY) * 1.05

                ZStack(alignment: .topLeading) {
                    Color.clear
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: start.width, height: start.height)
                        .clipShape(RoundedRectangle(
                            cornerRadius: expansionActive ? 0 : 32,
                            style: .continuous
                        ))
                        .scaleEffect(
                            expansionActive ? targetScale : 1.0,
                            anchor: .center
                        )
                        .animation(
                            .spring(response: 0.75, dampingFraction: 0.82, blendDuration: 0),
                            value: expansionActive
                        )
                        .padding(.leading, start.minX)
                        .padding(.top, start.minY)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(50)
                .onAppear {
                    // Give SwiftUI a real breathing frame (~2 frames at 60Hz)
                    // to commit the initial render at scale 1.0 before we
                    // flip expansionActive. Without this delay SwiftUI
                    // coalesces the writes and the scale snaps straight to
                    // targetScale.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                        expansionActive = true
                        withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                            session.hidesTabBar = true
                        }
                    }
                }
            }
        }
        // Single spring for both the photo and the scanning overlay —
        // consistent timing so nothing lags behind anything else. Soft
        // overshoot for the Duolingo bounce as the photo settles into fullscreen.
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
        // Tap-outside-to-close via .onTapGesture on the outer ZStack. Unlike
        // simultaneousGesture, this respects child buttons' tap priority —
        // if you tap a Button (orange scan, Camera row, Photos row, pantry
        // items, etc.), that button's action fires and this gesture does NOT.
        // Only fires when the tap lands on non-interactive background.
        .onTapGesture(coordinateSpace: .global) { location in
            guard showActionMenu, !showCameraPanel, !showPhotosPicker else { return }
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
                            .opacity(showCameraPanel ? 0 : 1)
                            .scaleEffect(showCameraPanel ? 0.95 : 1.0)
                        // Divider + Photos row are ALWAYS mounted. Their frame
                        // and opacity are tied to showCameraPanel so they
                        // interpolate smoothly along the same spring — never
                        // binary appear/disappear.
                        // Concrete collapsed/expanded heights (NOT nil) so the
                        // row interpolates continuously along the close spring.
                        // Animating a frame height to `nil` can't interpolate —
                        // it holds at 0 and snaps open only when the spring ends,
                        // which is what made the Photos row "blink back" on close.
                        Divider().overlay(Color.fridjText.opacity(0.08))
                            .opacity(showCameraPanel ? 0 : 1)
                        morphRow(icon: "photo.on.rectangle", title: "Photos",
                                 tint: .fridjOrange, foreground: .fridjText,
                                 action: openPhotosFromMenu)
                            .opacity(showCameraPanel ? 0 : 1)
                            .scaleEffect(showCameraPanel ? 0.95 : 1.0)
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
        .frame(height: showCameraPanel ? expandedPanelHeight : nil)
        // Camera preview + controls live OVER the pill's own background — so
        // it's literally the SAME shape hosting different content depending on
        // state. When collapsed, the overlay is invisible (opacity 0).
        .overlay {
            embeddedCameraPanel
                .opacity(showCameraPanel ? 1 : 0)
                .allowsHitTesting(showCameraPanel)
        }
        .background(
            RoundedRectangle(cornerRadius: showCameraPanel ? 32 : FridjRadius.scanButton,
                             style: .continuous)
                .fill(showCameraPanel ? Color.fridjDark : (showActionMenu ? Color.white : Color.fridjOrange))
        )
        .overlay(
            RoundedRectangle(cornerRadius: showCameraPanel ? 32 : FridjRadius.scanButton,
                             style: .continuous)
                .stroke(Color.fridjText.opacity(showActionMenu && !showCameraPanel ? 0.06 : 0),
                        lineWidth: 1)
        )
        .shadow(color: .black.opacity((showActionMenu || showCameraPanel) ? 0.15 : 0),
                radius: (showActionMenu || showCameraPanel) ? 22 : 0,
                y: (showActionMenu || showCameraPanel) ? 10 : 0)
        .clipShape(RoundedRectangle(cornerRadius: showCameraPanel ? 32 : FridjRadius.scanButton,
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
        scanError = nil
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
        // Menu stays OPEN — the photo picker just presents on top of it. When
        // user cancels the picker, they see the menu again (persistent state).
        // If they pick a photo, the scan flow takes over and the menu naturally
        // goes away with the rest of the entry view.
        cameraController.stop()
        showPhotosPicker = true
    }

    // MARK: Camera panel

    private func openCameraPanel() {
        scanError = nil
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
        // Re-entrancy guard — if we're already in the middle of an expansion,
        // ignore. Prevents state getting stuck when the animation is interrupted
        // (e.g. a screenshot mid-flight) and the shutter is somehow re-fired.
        guard expandingImage == nil else { return }

        let displayImage = ImagePrep.downscale(img, maxEdge: 1200)

        session.showScanFound = false
        session.showScanOverview = false
        pickerItem = nil

        // 1. Reset expansionActive to guarantee a clean scale=1.0 start, then
        //    snapshot the panel's frame and seed the overlay. The overlay's
        //    .onAppear will kick off the actual zoom animation once SwiftUI
        //    has committed a render at the starting scale.
        expansionActive = false
        expansionStartFrame = actionButtonFrame
        expandingImage = displayImage

        // 2. AFTER the overlay reaches fullscreen: commit to the scanning
        //    stage. Everything that happens now — panel collapsing, entryView
        //    disappearing, fullscreen bg photo fading in — is hidden underneath
        //    the fullscreen overlay. Zero visible flash. Delay = onAppear
        //    breathing frame (0.033s) + spring settle time (~0.85s).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            capturedImage = displayImage
            showCameraPanel = false
            showActionMenu = false
            panelKeepsPreview = false
            cameraController.stop()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82, blendDuration: 0)) {
                localStage = .scanning
            }
            // 3. Wait for the fullscreen bg photo to fully fade in behind the
            //    overlay, THEN remove the overlay. Reset expansionActive FIRST
            //    so a subsequent capture always starts from scale 1.0.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                expansionActive = false
                expandingImage = nil
            }
        }

        Task.detached {
            try? await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: img)
            }
        }
        // Store the scan task so the Cancel button can abort it.
        scanTask?.cancel()
        scanTask = Task { await runScan(displayImage) }
    }

    // Called from the Cancel button in ScanningView. Cancels the URLSession
    // request in flight and returns the UI to the entry state — no API charge.
    private func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            localStage = .entry
            capturedImage = nil
            session.hidesTabBar = false
        }
        expansionActive = false
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
            // If the user cancelled after the request completed but before
            // we processed the result, don't apply it.
            if Task.isCancelled { return }

            // Hop explicitly to the main actor. Even though this Task is
            // inherited from a main-actor caller, the network suspend point
            // can leave us in an ambient state where a single-transaction
            // withAnimation doesn't consistently propagate through the
            // @Observable singleton to ContentView's tab-bar modifiers.
            // Splitting the writes into distinct main-actor animations makes
            // each one fire reliably.
            await MainActor.run {
                let highConfidence = items.filter { $0.confidence == .high }
                store.mergeScan(highConfidence)
                session.scanDetectedItems = items

                // 1. Bring the tab bar back FIRST, on its own animation. The
                //    ContentView reads session.hidesTabBar for offset/opacity
                //    on the ExpandableTabBar — this write must land before we
                //    flip showScanFound, or the found panel morphs into a
                //    tab bar that's still off-screen.
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    session.hidesTabBar = false
                }
                // 2. Then transition the coordinator to review state — the
                //    tab bar (now on-screen) expands into the found panel.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    localStage = .entry
                    session.showScanFound = true
                }
            }
        } catch {
            // Cancellation: exit quietly, cancelScan() already reset the UI.
            if Task.isCancelled { return }
            if (error as NSError).code == NSURLErrorCancelled { return }
            await MainActor.run {
                scanError = error.localizedDescription
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                    session.hidesTabBar = false
                }
                withAnimation(.easeInOut(duration: 0.35)) {
                    localStage = .entry
                    capturedImage = nil
                }
                session.showScanFound = false
            }
        }
    }

    // MARK: Helpers

    private func resetToEntry() {
        session.showScanFound = false
        capturedImage = nil
        pickerItem = nil
        localStage = .entry
        expansionActive = false
        expandingImage = nil
        session.hidesTabBar = false
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

        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
            capturedImage = displayImage
            localStage = .scanning
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
