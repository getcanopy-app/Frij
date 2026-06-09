import SwiftUI

// Overlay-only — coordinator owns the photo background.
struct ScanningView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Text("Hold still..")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)

            Text("We're scanning your fridge\nfor fresh ideas")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Spacer()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ScanningView()
    }
}
