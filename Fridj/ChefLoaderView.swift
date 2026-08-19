import SwiftUI

/// A refined little chef watching over a steaming pot — shown while Frij is
/// generating meals or loading a dish photo. Built entirely from SwiftUI
/// vectors (no emoji, no image assets) so it renders identically on device and
/// in the simulator. Calm and warm rather than cutesy: no blush, a subtle
/// smile, elegant curling steam, and a soft heat glow.
struct ChefLoaderView: View {
    var size: CGFloat = 128
    /// Compact = just the toque + face (no pot/steam/glow), for thumbnail-sized
    /// loading placeholders where the full scene would be too busy.
    var compact: Bool = false

    @State private var bob = false
    @State private var steam = false
    @State private var glow = false

    private let skin = Color(red: 0.99, green: 0.83, blue: 0.67)
    private let hat  = Color.white
    private let pot  = Color(red: 0.20, green: 0.18, blue: 0.17)

    var body: some View {
        ZStack {
            if !compact { heatGlow }
            if !compact { steamWisps }

            VStack(spacing: -size * 0.06) {
                chefHead
                if !compact { simmerPot }
            }
            .offset(y: bob ? -size * 0.028 : size * 0.028)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bob)
        }
        .frame(width: size, height: compact ? size : size * 1.28)
        .onAppear { bob = true; steam = true; glow = true }
        .accessibilityLabel("Cooking up ideas")
    }

    // MARK: Head (toque + calm face)

    private var chefHead: some View {
        ZStack {
            Circle()
                .fill(skin)
                .frame(width: size * 0.5, height: size * 0.5)
                .overlay(faceFeatures)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 3)

            toque.offset(y: -size * 0.35)
        }
        .frame(height: size * 0.66)
    }

    private var toque: some View {
        ZStack {
            // soft, well-rounded puff
            HStack(spacing: -size * 0.075) {
                Circle().fill(hat).frame(width: size * 0.20, height: size * 0.20)
                Circle().fill(hat).frame(width: size * 0.28, height: size * 0.28)
                Circle().fill(hat).frame(width: size * 0.20, height: size * 0.20)
            }
            .offset(y: -size * 0.05)
            // fitted band
            RoundedRectangle(cornerRadius: size * 0.045)
                .fill(hat)
                .frame(width: size * 0.40, height: size * 0.13)
                .offset(y: size * 0.085)
        }
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }

    private var faceFeatures: some View {
        ZStack {
            HStack(spacing: size * 0.14) {
                eye; eye
            }
            .offset(y: -size * 0.015)
            // a small, calm smile
            Smile()
                .stroke(Color.fridjText.opacity(0.72),
                        style: StrokeStyle(lineWidth: size * 0.017, lineCap: .round))
                .frame(width: size * 0.12, height: size * 0.06)
                .offset(y: size * 0.085)
        }
    }

    private var eye: some View {
        Circle()
            .fill(Color.fridjText.opacity(0.82))
            .frame(width: size * 0.032, height: size * 0.032)
    }

    // MARK: Pot

    private var simmerPot: some View {
        ZStack {
            // body
            UnevenRoundedRectangle(
                topLeadingRadius: size * 0.02, bottomLeadingRadius: size * 0.09,
                bottomTrailingRadius: size * 0.09, topTrailingRadius: size * 0.02
            )
            .fill(pot)
            .frame(width: size * 0.40, height: size * 0.17)
            // rim
            Capsule()
                .fill(pot)
                .frame(width: size * 0.46, height: size * 0.055)
                .offset(y: -size * 0.085)
            // little handles
            HStack {
                Circle().stroke(pot, lineWidth: size * 0.028)
                    .frame(width: size * 0.07, height: size * 0.07)
                Spacer()
                Circle().stroke(pot, lineWidth: size * 0.028)
                    .frame(width: size * 0.07, height: size * 0.07)
            }
            .frame(width: size * 0.52)
            .offset(y: -size * 0.02)
        }
    }

    // MARK: Ambience

    private var steamWisps: some View {
        HStack(spacing: size * 0.10) {
            ForEach(0..<3, id: \.self) { i in
                SteamWisp()
                    .stroke(Color.fridjText.opacity(0.22),
                            style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                    .frame(width: size * 0.09, height: size * 0.30)
                    .opacity(steam ? 0 : 0.85)
                    .offset(y: steam ? -size * 0.16 : size * 0.02)
                    .animation(.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.4), value: steam)
            }
        }
        .offset(y: size * 0.18)
    }

    private var heatGlow: some View {
        Circle()
            .fill(RadialGradient(colors: [Color.fridjOrange.opacity(0.18), .clear],
                                 center: .center, startRadius: 0, endRadius: size * 0.6))
            .frame(width: size * 1.3, height: size * 1.3)
            .scaleEffect(glow ? 1.06 : 0.92)
            .opacity(glow ? 0.9 : 0.5)
            .offset(y: size * 0.22)
            .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: glow)
    }
}

/// A small, calm upturned smile.
private struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 1.9))
        return p
    }
}

/// A gently curling steam wisp (an S-curve).
private struct SteamWisp: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.midX, y: r.midY),
                   control1: CGPoint(x: r.midX + w * 0.85, y: r.maxY - r.height * 0.16),
                   control2: CGPoint(x: r.midX - w * 0.85, y: r.midY + r.height * 0.14))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY),
                   control1: CGPoint(x: r.midX + w * 0.85, y: r.midY - r.height * 0.14),
                   control2: CGPoint(x: r.midX - w * 0.6, y: r.minY + r.height * 0.12))
        return p
    }
}

#Preview {
    ZStack {
        Color.fridjBg.ignoresSafeArea()
        ChefLoaderView(size: 132)
    }
}
