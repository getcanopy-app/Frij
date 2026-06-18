import SwiftUI

struct ScanningView: View {
    @State private var isPulsing = false
    @State private var scanLineY: CGFloat = -0.42

    var body: some View {
        ZStack {
            // Scanning line sweeps top → bottom → top
            GeometryReader { geo in
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, .white.opacity(0.45), .white.opacity(0.85), .white.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(height: 2)
                    .blur(radius: 1.5)
                    .frame(maxWidth: .infinity)
                    .offset(y: (0.5 + scanLineY) * geo.size.height)
                    .animation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true), value: scanLineY)
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Spacer()

                Text("Hold still..")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                    .opacity(isPulsing ? 1.0 : 0.6)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)

                Text("We're scanning your fridge\nfor fresh ideas")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isPulsing = true
            scanLineY = 0.42
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ScanningView()
    }
}
