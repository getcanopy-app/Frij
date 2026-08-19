import SwiftUI

/// Frij's cooking mascot — a compact, friendly chef with a big handlebar
/// mustache and a bowtie, shown while meals generate or a dish photo loads.
/// Bold flat-design character energy (big eyes, soft cheeks, button nose), an
/// original take on the classic mustachioed chef. Pure SwiftUI vectors so it
/// renders identically on device and in the simulator.
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
    private let skinD = Color(red: 0.95, green: 0.72, blue: 0.55)   // deeper skin (nose/ears)
    private let hat   = Color.white
    private let brown = Color(red: 0.40, green: 0.24, blue: 0.13)

    var body: some View {
        ZStack {
            if !compact { heatGlow }
            if !compact { steamWisps }

            VStack(spacing: -size * 0.11) {
                head
                if !compact { bowtie }
            }
            .offset(y: bob ? -size * 0.028 : size * 0.028)
            .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bob)
        }
        .frame(width: size, height: compact ? size : size * 1.16)
        .onAppear { bob = true; steam = true; glow = true; wiggle = true }
        .accessibilityLabel("Cooking up ideas")
    }

    // MARK: Head

    private var head: some View {
        ZStack {
            // ears peeking at the sides
            ear.offset(x: -size * 0.28, y: size * 0.03)
            ear.offset(x:  size * 0.28, y: size * 0.03)

            // compact rounded face with soft bottom shading for form
            Ellipse()
                .fill(skin)
                .frame(width: size * 0.6, height: size * 0.57)
                .overlay(
                    Ellipse().fill(
                        LinearGradient(colors: [.clear, brown.opacity(0.07)],
                                       startPoint: .center, endPoint: .bottom))
                )
                .overlay(face)
                .clipShape(Ellipse())
                .shadow(color: .black.opacity(0.06), radius: 5, y: 3)

            toque.offset(y: -size * 0.28)
        }
        .frame(height: size * 0.66)
    }

    private var ear: some View {
        Ellipse().fill(skinD)
            .frame(width: size * 0.085, height: size * 0.12)
    }

    private var face: some View {
        ZStack {
            // soft cheeks
            cheek.offset(x: -size * 0.185, y: size * 0.06)
            cheek.offset(x:  size * 0.185, y: size * 0.06)

            // brows
            brow(flip: false).offset(x: -size * 0.105, y: -size * 0.115)
            brow(flip: true).offset(x:  size * 0.105, y: -size * 0.115)

            // big friendly eyes
            eye.offset(x: -size * 0.095, y: -size * 0.05)
            eye.offset(x:  size * 0.095, y: -size * 0.05)

            // button nose with highlight
            nose.offset(y: size * 0.035)

            // signature handlebar mustache (gently wiggling), tucked under nose
            Mustache()
                .fill(brown)
                .frame(width: size * 0.4, height: size * 0.19)
                .rotationEffect(.degrees(wiggle ? 1.6 : -1.6))
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: wiggle)
                .offset(y: size * 0.125)
        }
    }

    private var cheek: some View {
        Circle().fill(Color.fridjCoral.opacity(0.22))
            .frame(width: size * 0.1, height: size * 0.1)
            .blur(radius: size * 0.02)
    }

    private func brow(flip: Bool) -> some View {
        Capsule().fill(brown)
            .frame(width: size * 0.11, height: size * 0.03)
            .rotationEffect(.degrees(flip ? 10 : -10))
    }

    private var eye: some View {
        ZStack {
            Capsule().fill(.white)
                .frame(width: size * 0.09, height: size * 0.115)
            Circle().fill(Color.fridjText)
                .frame(width: size * 0.058, height: size * 0.058)
                .offset(y: size * 0.012)
            Circle().fill(.white)
                .frame(width: size * 0.021, height: size * 0.021)
                .offset(x: size * 0.016, y: -size * 0.013)
        }
    }

    private var nose: some View {
        ZStack {
            Ellipse().fill(skinD)
                .frame(width: size * 0.07, height: size * 0.052)
            Circle().fill(Color.white.opacity(0.55))
                .frame(width: size * 0.02, height: size * 0.02)
                .offset(x: -size * 0.011, y: -size * 0.008)
        }
    }

    private var toque: some View {
        ZStack {
            HStack(spacing: -size * 0.07) {
                Circle().fill(hat).frame(width: size * 0.2, height: size * 0.2)
                Circle().fill(hat).frame(width: size * 0.27, height: size * 0.27)
                Circle().fill(hat).frame(width: size * 0.2, height: size * 0.2)
            }
            .offset(y: -size * 0.045)
            // soft fold shadow where puff meets band
            Capsule().fill(Color.black.opacity(0.04))
                .frame(width: size * 0.38, height: size * 0.03)
                .offset(y: size * 0.025)
            // band
            RoundedRectangle(cornerRadius: size * 0.045)
                .fill(hat)
                .frame(width: size * 0.44, height: size * 0.14)
                .offset(y: size * 0.085)
        }
        .shadow(color: .black.opacity(0.05), radius: 3, y: 2)
    }

    // MARK: Bowtie

    private var bowtie: some View {
        HStack(spacing: -size * 0.01) {
            Triangle().fill(Color.fridjCoral)
                .frame(width: size * 0.13, height: size * 0.14)
                .rotationEffect(.degrees(-90))
            Circle().fill(Color.fridjCoral.opacity(0.92))
                .frame(width: size * 0.055, height: size * 0.055)
                .zIndex(1)
            Triangle().fill(Color.fridjCoral)
                .frame(width: size * 0.13, height: size * 0.14)
                .rotationEffect(.degrees(90))
        }
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
    }

    // MARK: Ambience

    private var steamWisps: some View {
        HStack(spacing: size * 0.11) {
            ForEach(0..<3, id: \.self) { i in
                SteamWisp()
                    .stroke(Color.fridjText.opacity(0.2),
                            style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                    .frame(width: size * 0.09, height: size * 0.26)
                    .opacity(steam ? 0 : 0.8)
                    .offset(y: steam ? -size * 0.15 : size * 0.02)
                    .animation(.easeOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.4), value: steam)
            }
        }
        .offset(y: -size * 0.52)
    }

    private var heatGlow: some View {
        Circle()
            .fill(RadialGradient(colors: [Color.fridjOrange.opacity(0.16), .clear],
                                 center: .center, startRadius: 0, endRadius: size * 0.52))
            .frame(width: size * 1.2, height: size * 1.2)
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
        p.move(to: pt(0.5, 0.34))
        p.addQuadCurve(to: pt(0.05, 0.06), control: pt(0.27, -0.07)) // sharp left tip
        p.addQuadCurve(to: pt(0.25, 0.80), control: pt(-0.03, 0.55)) // left lobe
        p.addQuadCurve(to: pt(0.5, 0.66),  control: pt(0.40, 0.95))  // center bottom
        p.addQuadCurve(to: pt(0.75, 0.80), control: pt(0.60, 0.95))  // right lobe
        p.addQuadCurve(to: pt(0.95, 0.06), control: pt(1.03, 0.55))  // sharp right tip
        p.addQuadCurve(to: pt(0.5, 0.34),  control: pt(0.73, -0.07))
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
        ChefLoaderView(size: 150)
    }
}
