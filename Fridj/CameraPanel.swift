import SwiftUI
import AVFoundation
import UIKit

// MARK: - Session controller

final class CameraSessionController: NSObject {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "frij.camera.session", qos: .userInitiated)
    private var photoOutput: AVCapturePhotoOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var configured = false
    private var captureCompletion: ((UIImage?) -> Void)?

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, let out = self.photoOutput else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            self.captureCompletion = completion
            let settings = AVCapturePhotoSettings()
            out.capturePhoto(with: settings, delegate: self)
        }
    }

    func flip() {
        sessionQueue.async { [weak self] in
            guard let self, let current = self.currentInput else { return }
            let newPosition: AVCaptureDevice.Position =
                current.device.position == .back ? .front : .back
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                          for: .video,
                                                          position: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else { return }
            self.session.beginConfiguration()
            self.session.removeInput(current)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            } else {
                self.session.addInput(current)
            }
            self.session.commitConfiguration()
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            currentInput = input
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            photoOutput = output
        }
        session.commitConfiguration()
        configured = true
    }
}

extension CameraSessionController: AVCapturePhotoCaptureDelegate {
    // AVFoundation calls this on a background queue, so it MUST be nonisolated.
    // We hop back to main before touching captureCompletion.
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                self?.captureCompletion?(image)
                self?.captureCompletion = nil
            }
        }
    }
}

// MARK: - Preview layer

struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    // Explicit sublayer + layoutSubviews (instead of layerClass override)
    // because layerClass gives you a layer whose bounds are updated by
    // UIKit with implicit CA animations. During a SwiftUI resize spring,
    // those implicit animations lag behind SwiftUI's layout, leaving the
    // preview stuck at its pre-animation size — which is what caused the
    // dead-black band at the bottom of the panel. Setting frame inside a
    // CATransaction with actions disabled makes bounds snap instantly.
    final class PreviewView: UIView {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.addSublayer(videoPreviewLayer)
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            videoPreviewLayer.frame = bounds
            CATransaction.commit()
        }
    }
}

// MARK: - Action menu (Camera + Photos rows, ChatGPT-style)

struct ScanActionMenu: View {
    let cornerRadius: CGFloat
    let onCamera: () -> Void
    let onPhotos: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            row(icon: "camera.fill", title: "Camera", action: onCamera)
            Divider()
                .overlay(Color.fridjText.opacity(0.08))
            row(icon: "photo.on.rectangle", title: "Photos", action: onPhotos)
        }
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.fridjText.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 22, y: 10)
    }

    private func row(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.fridjOrange)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .font(FridjFont.size(16, weight: .semibold))
                    .foregroundColor(.fridjText)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panel

struct CameraPanel: View {
    let controller: CameraSessionController
    let cornerRadius: CGFloat
    // Driven externally — parent turns the session on/off so the camera never
    // runs when the panel is invisible.
    let isActive: Bool
    let onCapture: (UIImage) -> Void
    let onDismiss: () -> Void
    let onPickLibrary: () -> Void

    @State private var previewVisible = false
    @State private var controlsVisible = false   // delayed drop-in for shutter + top buttons
    @State private var isCapturing = false
    @State private var flashOpacity: Double = 0
    // Frozen still shown on top of the live preview immediately after capture,
    // so the user's eye registers the shot before the panel expands.
    @State private var capturedStill: UIImage?

    var body: some View {
        ZStack {
            // Background — starts white (matches the menu row it grew out of),
            // fades to dark as the camera preview appears.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(previewVisible ? Color.fridjDark : Color.white)

            // Live preview: permanently mounted so the outer container can
            // treat it as a bound-in layer. blur + opacity + scale are all
            // bound to previewVisible so on close it dissolves elegantly
            // (accordion compression) rather than looking raw or distorted.
            // frame(maxHeight: .infinity) forces the UIViewRepresentable to
            // fill the ZStack — without it, the preview only grows to its
            // intrinsic content bounds and leaves a black gap at the bottom.
            CameraPreviewLayerView(session: controller.session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: previewVisible ? 0 : 16)
                .opacity(previewVisible ? 1 : 0)
                .scaleEffect(previewVisible ? 1.0 : 0.92)

            // Shutter flash
            Rectangle()
                .fill(Color.white)
                .opacity(flashOpacity)
                .allowsHitTesting(false)

            // Frozen still — appears the instant capture completes, sits above
            // the live preview and the flash so what the user sees IS the shot
            // they took. Held here for a brief beat before the coordinator
            // starts the fullscreen expansion.
            if let still = capturedStill {
                Image(uiImage: still)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Controls — DROP into place with an extra-bouncy spring at the
            // moment the panel completes its first bounce. This makes them
            // feel like the physical impact of the panel snapping into place
            // dropped them in.
            if controlsVisible && capturedStill == nil {
                VStack {
                    HStack {
                        controlButton(system: "xmark") { onDismiss() }
                        Spacer()
                        controlButton(system: "arrow.triangle.2.circlepath") {
                            controller.flip()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                    Spacer()

                    HStack(alignment: .center) {
                        Button { onPickLibrary() } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.white.opacity(0.18), in: Circle())
                        }

                        Spacer()

                        Button { triggerCapture() } label: {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.9), lineWidth: 4)
                                    .frame(width: 78, height: 78)
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 62, height: 62)
                                    .scaleEffect(isCapturing ? 0.85 : 1)
                                    .animation(.easeOut(duration: 0.12), value: isCapturing)
                            }
                        }
                        .disabled(isCapturing)

                        Spacer()

                        // Placeholder to balance the layout with the library button.
                        Color.clear.frame(width: 52, height: 52)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        // Clip everything to the morphing shape — the preview and controls
        // stay INSIDE the container as it grows from menu-row size up to
        // full panel size, so nothing spills out during the morph.
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: isActive) {
            if isActive {
                await bootstrap()
            } else {
                controller.stop()
                // DISMISSAL: content drops to opacity 0 INSTANTLY (first 10% of
                // timeline per Gemini's spec) — 0.036s ~= 10% of the 0.36s spring.
                // Prevents any distorted squished UI during the shape collapse.
                withAnimation(.easeOut(duration: 0.036)) {
                    controlsVisible = false
                    previewVisible = false
                }
            }
        }
    }

    @ViewBuilder
    private func controlButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Color.black.opacity(0.35), in: Circle())
        }
    }

    private func triggerCapture() {
        guard previewVisible, !isCapturing else { return }
        isCapturing = true
        // Quick white flash for feedback.
        withAnimation(.easeOut(duration: 0.08)) { flashOpacity = 0.85 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.easeIn(duration: 0.18)) { flashOpacity = 0 }
        }
        controller.capturePhoto { img in
            isCapturing = false
            guard let img else { return }
            // Freeze the exact frame the user shot, hold briefly, then let the
            // coordinator start the fullscreen expansion.
            withAnimation(.easeOut(duration: 0.08)) {
                capturedStill = img
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                onCapture(img)
            }
        }
    }

    private func bootstrap() async {
        // Fresh session — clear any leftover still from a prior capture.
        capturedStill = nil
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            controller.start()   // no-op if already running (pre-warmed on menu open)
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted { controller.start() } else { return }
        default:
            return
        }
        // Preview scales up from 0.92 → 1.0 during the panel's expansion,
        // matched roughly to expansion speed.
        withAnimation(.easeOut(duration: 0.28)) { previewVisible = true }
        // Controls drop in right away — no dead-air black gap at the bottom
        // while the camera hardware is still warming up. The shutter being
        // on-screen from the start makes the whole panel feel intentional.
        withAnimation(.spring(response: 0.34, dampingFraction: 0.72, blendDuration: 0)) {
            controlsVisible = true
        }
    }
}
