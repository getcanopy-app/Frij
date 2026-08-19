import SwiftUI

/// Frij's cooking mascot — a bold, friendly chef with a big handlebar mustache
/// and a bowtie, shown while meals generate or a dish photo loads. Clean
/// flat-design character energy (big expressive eyes, confident shapes), an
/// original take on the classic mustachioed-chef trope. Pure SwiftUI vectors so
/// it renders identically on device and in the simulator.
struct ChefLoaderView: View {
    var size: CGFloat = 128
    /// Compact = just the head (toque + face), no bowtie/steam/glow — for
    /// thumbnail-sized loading placeholders.
    var compact: Bool = false

    @State private var bob = false
    @State private var steam = false
    @State private var glow = false
    @State private var wiggle = false

    private let skin  = Color(red: 0.99, green: 0.83, blue: 0.67)
    private let hat   = Color.white
    private let brown = Color(red: 0.40, green: 0.24, blue: 0.13)

    var body: some View {
        ZStack {
            if !compact { heatGlow }
            if !compact { steamWisps }

            VStack(spacing: -size * 0.14) {
                head
                if !compact { bowtie }
            }
            .offset(y: bob ? -size * 0.03 : size * 0.03)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bob)
        }
        .frame(width: size, height: compact ? size : size * 1.24)
        .onAppear { bob = true; steam = true; glow = true; wiggle = true }
        .accessibilityLabel("Cooking up ideas")
    }

    // MARK: Head

    private var head: some View {
        ZStack {
            Circle()
                .fill(skin)
                .frame(width: size * 0.56, height: size * 0.56)
                .overlay(face)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 3)

            toque.offset(y: -size * 0.36)
        }
        .frame(height: size * 0.72)
    }

    private var face: some View {
        ZStack {
            // brows
            HStack(spacing: size * 0.13) {
                brow(flip: false); brow(flip: true)
            }
            .offset(y: -size * 0.115)

            // big friendly eyes
            HStack(spacing: size * 0.115) {
                eye; eye
            }
            .offset(y: -size * 0.055)

            // little nose
            Ellipse()
                .fill(skin.opacity(0.001).blendMode(.multiply))
                .frame(width: size * 0.05, height: size * 0.04)
                .overlay(Ellipse().fill(Color.black.opacity(0.06)))
                .offset(y: size * 0.01)

            // signature handlebar mustache (gently wiggling)
            Mustache()
                .fill(brown)
                .frame(width: size * 0.42, height: size * 0.2)
                .rotationEffect(.degrees(wiggle ? 1.6 : -1.6))
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: wiggle)
                .offset(y: size * 0.08)
        }
    }

    private func brow(flip: Bool) -> some View {
        Capsule()
            .fill(brown)
            .frame(width: size * 0.11, height: size * 0.032)
            .rotationEffect(.degrees(flip ? 9 : -9))
    }

    private var eye: some View {
        ZStack {
            Capsule().fill(.white)
                .frame(width: size * 0.085, height: size * 0.11)
            Circle().fill(Color.fridjText)
                .frame(width: size * 0.055, height: size * 0.055)
                .offset(y: size * 0.012)
            Circle().fill(.white)
                .frame(width: size * 0.02, height: size * 0.02)
                .offset(x: size * 0.015, y: -size * 0.012)
        }
    }

    private var toque: some View {
        ZStack {
            HStack(spacing: -size * 0.075) {
                Circle().fill(hat).frame(width: size * 0.21, height: size * 0.21)
                Circle().fill(hat).frame(width: size * 0.29, height: size * 0.29)
                Circle().fill(hat).frame(width: size * 0.21, height: size * 0.21)
            }
            .offset(y: -size * 0.05)
            RoundedRectangle(cornerRadius: size * 0.045)
                .fill(hat)
                .frame(width: size * 0.42, height: size * 0.14)
                .offset(y: size * 0.085)
        }
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }

    // MARK: Bowtie

    private var bowtie: some View {
        HStack(spacing: -size * 0.01) {
            Triangle().fill(Color.fridjCoral)
                .frame(width: size * 0.14, height: size * 0.15)
                .rotationEffect(.degrees(-90))
            Circle().fill(Color.fridjCoral.opacity(0.92))
                .frame(width: size * 0.06, height: size * 0.06)
                .zIndex(1)
            Triangle().fill(Color.fridjCoral)
                .frame(width: size * 0.14, height: size * 0.15)
                .rotationEffect(.degrees(90))
        }
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    // MARK: Ambience

    private var steamWisps: some View {
        HStack(spacing: size * 0.11) {
            ForEach(0..<3, id: \.self) { i in
                SteamWisp()
                    .stroke(Color.fridjText.opacity(0.20),
                            style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                    .frame(width: size * 0.09, height: size * 0.28)
                    .opacity(steam ? 0 : 0.8)
                    .offset(y: steam ? -size * 0.16 : size * 0.02)
                    .animation(.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.4), value: steam)
            }
        }
        .offset(y: -size * 0.5)
    }

    private var heatGlow: some View {
        Circle()
            .fill(RadialGradient(colors: [Color.fridjOrange.opacity(0.16), .clear],
                                 center: .center, startRadius: 0, endRadius: size * 0.55))
            .frame(width: size * 1.25, height: size * 1.25)
            .scaleEffect(glow ? 1.06 : 0.92)
            .opacity(glow ? 0.9 : 0.55)
            .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: glow)
    }
}

/// A bold, friendly handlebar mustache with up-curled tips.
private struct Mustache: Shape {
    func path(in r: CGRect) -> Path {
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height)
        }
        var p = Path()
        p.move(to: pt(0.5, 0.34))                                    // center top (under nose)
        p.addQuadCurve(to: pt(0.05, 0.06), control: pt(0.27, -0.07)) // up to sharp left tip
        p.addQuadCurve(to: pt(0.25, 0.80), control: pt(-0.03, 0.55)) // curl down to left lobe
        p.addQuadCurve(to: pt(0.5, 0.66),  control: pt(0.40, 0.95))  // to center bottom (shallow)
        p.addQuadCurve(to: pt(0.75, 0.80), control: pt(0.60, 0.95))  // to right lobe
        p.addQuadCurve(to: pt(0.95, 0.06), control: pt(1.03, 0.55))  // up to sharp right tip
        p.addQuadCurve(to: pt(0.5, 0.34),  control: pt(0.73, -0.07)) // back to center top
        p.closeSubpath()
        return p
    }
}

/// An upward-pointing triangle (rotated to form bowtie wings).
private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
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
        ChefLoaderView(size: 140)
    }
}
