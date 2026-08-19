import SwiftUI

/// A cute little chef who bobs, tosses food in a pan, and steams — shown while
/// Frij is generating meals. Built entirely from SwiftUI vectors (no emoji, no
/// image assets) so it renders identically on device and in the simulator.
struct ChefLoaderView: View {
    var size: CGFloat = 128
    /// Compact = just the bobbing head + hat, no pan/steam. For thumbnail-sized
    /// loading placeholders where the full scene would be too busy.
    var compact: Bool = false

    @State private var bob = false
    @State private var toss = false
    @State private var steam = false

    private let skin = Color(red: 0.99, green: 0.82, blue: 0.65)
    private let hat  = Color.white

    var body: some View {
        ZStack {
            if !compact { steamWisps }
            chef
                .offset(y: bob ? -size * 0.05 : size * 0.03)
                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: bob)
        }
        .frame(width: size, height: compact ? size : size * 1.2)
        .onAppear { bob = true; toss = true; steam = true }
        .accessibilityLabel("Cooking up ideas")
    }

    // MARK: Chef (hat + face + pan)

    private var chef: some View {
        ZStack {
            Circle()
                .fill(skin)
                .frame(width: size * 0.6, height: size * 0.6)
                .overlay(faceFeatures)
                .shadow(color: .black.opacity(0.05), radius: 4, y: 3)

            chefHat.offset(y: -size * 0.44)
            if !compact { pan.offset(x: size * 0.02, y: size * 0.42) }
        }
    }

    private var chefHat: some View {
        ZStack {
            HStack(spacing: -size * 0.09) {
                Circle().fill(hat).frame(width: size * 0.24, height: size * 0.24)
                Circle().fill(hat).frame(width: size * 0.32, height: size * 0.32)
                Circle().fill(hat).frame(width: size * 0.24, height: size * 0.24)
            }
            .offset(y: -size * 0.05)
            RoundedRectangle(cornerRadius: size * 0.05)
                .fill(hat)
                .frame(width: size * 0.46, height: size * 0.15)
                .offset(y: size * 0.10)
        }
        .shadow(color: .black.opacity(0.06), radius: 3, y: 2)
    }

    private var faceFeatures: some View {
        ZStack {
            // eyes
            HStack(spacing: size * 0.15) {
                eye; eye
            }
            .offset(y: -size * 0.02)

            // rosy cheeks
            HStack(spacing: size * 0.28) {
                blush; blush
            }
            .offset(y: size * 0.06)

            // smile
            Smile()
                .stroke(Color.fridjText.opacity(0.78),
                        style: StrokeStyle(lineWidth: size * 0.02, lineCap: .round))
                .frame(width: size * 0.18, height: size * 0.1)
                .offset(y: size * 0.09)
        }
    }

    private var eye: some View {
        Capsule()
            .fill(Color.fridjText.opacity(0.85))
            .frame(width: size * 0.035, height: size * 0.06)
    }

    private var blush: some View {
        Circle()
            .fill(Color.fridjCoral.opacity(0.35))
            .frame(width: size * 0.08, height: size * 0.08)
            .blur(radius: size * 0.01)
    }

    // A little pan the chef flips food in.
    private var pan: some View {
        ZStack {
            // tossing morsel — arcs up out of the pan and back
            Circle()
                .fill(Color.fridjOrange)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(y: toss ? -size * 0.26 : -size * 0.04)
                .animation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true), value: toss)

            // pan body + handle, gently flipping
            ZStack {
                Capsule()
                    .fill(Color.fridjText.opacity(0.82))
                    .frame(width: size * 0.24, height: size * 0.05)
                    .offset(x: size * 0.27)
                Ellipse()
                    .fill(Color.fridjText.opacity(0.9))
                    .frame(width: size * 0.32, height: size * 0.09)
            }
            .rotationEffect(.degrees(toss ? -10 : 4), anchor: .center)
            .animation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true), value: toss)
        }
    }

    private var steamWisps: some View {
        HStack(spacing: size * 0.07) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(Color.fridjText.opacity(0.14))
                    .frame(width: size * 0.045, height: size * 0.17)
                    .offset(y: steam ? -size * 0.42 : -size * 0.22)
                    .opacity(steam ? 0 : 0.7)
                    .animation(.easeOut(duration: 1.3)
                        .repeatForever(autoreverses: false)
                        .delay(Double(i) * 0.32), value: steam)
            }
        }
        .offset(y: -size * 0.02)
    }
}

/// An upturned smile.
private struct Smile: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY * 1.7))
        return p
    }
}

#Preview {
    ZStack {
        Color.fridjBg.ignoresSafeArea()
        ChefLoaderView()
    }
}
