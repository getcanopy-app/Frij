import SwiftUI

// Fetches and displays an AI-generated photo for a dish name.
// Backend handles generation + caching; this caches the resolved URL in-memory
// so the same dish doesn't re-request within a session.
struct MealImageView: View {
    let dish: String
    var cornerRadius: CGFloat = 20

    @State private var url: URL?
    @State private var loadFailed = false
    @State private var retriedAfterFailure = false

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
                        // A cached URL can die (creator thumbnails on platform
                        // CDNs expire). Drop it and re-resolve once — the
                        // backend then serves/generates its own image.
                        placeholder(failed: true)
                            .task {
                                guard !retriedAfterFailure else { return }
                                retriedAfterFailure = true
                                MealImageCache.shared.remove(for: dish)
                                self.url = nil
                                await resolve()
                            }
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
            // Guard against a stale result landing after the dish prop changed
            // and the prior task was cancelled by .task(id: dish).
            guard !Task.isCancelled else { return }
            MealImageCache.shared.set(resolved, for: dish)
            url = resolved
        } catch {
            guard !Task.isCancelled else { return }
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

// Persistent cache of dish name -> resolved image URL. Survives app restarts.
final class MealImageCache {
    static let shared = MealImageCache()
    private let defaultsKey = "com.frij.mealImageURLs"
    private var map: [String: URL]

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            map = saved.compactMapValues { URL(string: $0) }
        } else {
            map = [:]
        }
        // One-time purge: these dishes were regenerated server-side (bad rolls
        // now at -v2 paths), but devices had the OLD urls cached here and would
        // never re-ask. Flag-guarded so the fresh URLs aren't re-purged.
        let purgeFlag = "frij.imageCache.purge.v2"
        if !UserDefaults.standard.bool(forKey: purgeFlag) {
            for dish in ["ramen", "shakshuka"] { map.removeValue(forKey: dish) }
            UserDefaults.standard.set(true, forKey: purgeFlag)
            persist()
        }
    }

    func url(for dish: String) -> URL? { map[dish.lowercased()] }

    /// Drop a dead entry (e.g. an expired creator-thumbnail CDN link) so the
    /// next resolve falls through to the backend.
    func remove(for dish: String) {
        map.removeValue(forKey: dish.lowercased())
        persist()
    }

    func set(_ url: URL, for dish: String) {
        map[dish.lowercased()] = url
        // Cap at 150 entries to prevent unbounded UserDefaults growth.
        if map.count > 150 {
            let overflow = map.count - 150
            map.keys.prefix(overflow).forEach { map.removeValue(forKey: $0) }
        }
        persist()
    }

    private func persist() {
        let strings = map.mapValues { $0.absoluteString }
        if let data = try? JSONEncoder().encode(strings) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}
