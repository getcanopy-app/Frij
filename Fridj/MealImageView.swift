import SwiftUI

// Fetches and displays an AI-generated photo for a dish name.
// Backend handles generation + caching; this caches the resolved URL in-memory
// so the same dish doesn't re-request within a session.
struct MealImageView: View {
    let dish: String
    var cornerRadius: CGFloat = 20

    @State private var url: URL?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder(failed: true)
                    case .empty:
                        ShimmerView()
                    @unknown default:
                        ShimmerView()
                    }
                }
            } else if loadFailed {
                placeholder(failed: true)
            } else {
                ShimmerView()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: dish) { await resolve() }
    }

    private func placeholder(failed: Bool) -> some View {
        ZStack {
            Color.fridjText.opacity(0.06)
            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.fridjText.opacity(0.25))
        }
    }

    private func resolve() async {
        // In-memory cache first.
        if let cached = MealImageCache.shared.url(for: dish) {
            url = cached
            return
        }
        do {
            let resolved = try await FrijAPI.mealImage(dish: dish)
            MealImageCache.shared.set(resolved, for: dish)
            url = resolved
        } catch {
            loadFailed = true
        }
    }
}

// Simple animated shimmer placeholder while the image loads/generates.
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { geo in
            Color.fridjText.opacity(0.08)
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                )
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1.6
                    }
                }
        }
    }
}

// Session-scoped cache of dish -> resolved image URL.
final class MealImageCache {
    static let shared = MealImageCache()
    private init() {}
    private var map: [String: URL] = [:]

    func url(for dish: String) -> URL? { map[dish.lowercased()] }
    func set(_ url: URL, for dish: String) { map[dish.lowercased()] = url }
}
