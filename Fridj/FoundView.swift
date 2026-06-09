import SwiftUI

// Sheet-friendly panel — no photo background, no floating bubbles.
// The sheet itself provides the background and the slide-up animation.
struct FoundView: View {
    let detected: [DetectedItem]
    let onContinue: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Dismiss handle row
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.15), in: Circle())
                }
                Spacer()
            }

            // "We found" header
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.yellow)
                Text("We found")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Two-column ingredient list
            let halves = splitHalves(detected)
            HStack(alignment: .top, spacing: 0) {
                ingredientColumn(halves.0)
                ingredientColumn(halves.1)
            }

            // Footer: count + continue button
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("x\(detected.count)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("ingredients\ndetected")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                }
                Spacer()
                Button(action: onContinue) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(Color.fridjOrange, in: Circle())
                }
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func ingredientColumn(_ items: [DetectedItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                Text("• \(item.item.capitalized)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func splitHalves(_ items: [DetectedItem]) -> ([DetectedItem], [DetectedItem]) {
        let mid = (items.count + 1) / 2
        return (Array(items.prefix(mid)), Array(items.dropFirst(mid)))
    }
}

#Preview {
    Color.gray.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            FoundView(
                detected: [
                    DetectedItem(item: "olive oil", confidence: .high),
                    DetectedItem(item: "salt", confidence: .high),
                    DetectedItem(item: "salmon", confidence: .high),
                    DetectedItem(item: "chocolate spread", confidence: .medium),
                    DetectedItem(item: "sugar", confidence: .high),
                    DetectedItem(item: "peanut butter", confidence: .high),
                ],
                onContinue: {},
                onDismiss: {}
            )
            .presentationDetents([.medium, .large])
            .presentationBackground(Color.black.opacity(0.85))
        }
}
