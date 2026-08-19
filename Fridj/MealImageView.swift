import SwiftUI

// Decoded-image cache. AsyncImage re-fetched and re-decoded on every screen
// switch; this loads a thumbnail's bytes over the network once (URLCache keeps
// them on disk), decodes once, and hands every later appearance the same
// UIImage instantly.
@MainActor
final class MealImageStore {
    static let shared = MealImageStore()
    private let decoded = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        decoded.countLimit = 120
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = URLCache(memoryCapacity: 20_000_000, diskCapacity: 250_000_000)
        // Generated images are immutable (cache-busts get new paths), so a
        // cached copy never needs revalidation.
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: cfg)
    }

    /// Instant, synchronous hit for images this session has already decoded.
    func cached(_ url: URL) -> UIImage? { decoded.object(forKey: url as NSURL) }

    func load(_ url: URL) async throws -> UIImage {
        if let hit = decoded.object(forKey: url as NSURL) { return hit }
        let (data, _) = try await session.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        decoded.setObject(image, forKey: url as NSURL)
        return image
    }
}

// Fetches and displays an AI-generated photo for a dish name.
// Backend handles generation + caching; MealImageCache remembers the resolved
// URL and MealImageStore holds the pixels.
struct MealImageView: View {
    let dish: String
    var cornerRadius: CGFloat = 20

    @State private var uiImage: UIImage?
    @State private var loadFailed = false

    init(dish: String, cornerRadius: CGFloat = 20) {
        self.dish = dish
        self.cornerRadius = cornerRadius
        // Synchronous cache peek so an already-seen thumbnail renders on the
        // first frame — no shimmer flash when switching screens.
        if let url = MealImageCache.shared.url(for: dish),
           let hit = MealImageStore.shared.cached(url) {
            _uiImage = State(initialValue: hit)
        }
    }

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                placeholder(failed: true)
            } else {
                loadingChef
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: dish) { await resolveAndLoad() }
    }

    // A little chef bobbing while the dish photo loads/generates. Sized to the
    // tile so it works on both big recipe images and small saved thumbnails.
    private var loadingChef: some View {
        GeometryReader { geo in
            let s = min(max(min(geo.size.width, geo.size.height) * 0.42, 26), 66)
            ZStack {
                LinearGradient(colors: [Color.fridjOrange.opacity(0.10),
                                        Color.fridjText.opacity(0.05)],
                               startPoint: .top, endPoint: .bottom)
                ChefLoaderView(size: s, compact: true)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func placeholder(failed: Bool) -> some View {
        ZStack {
            Color.fridjText.opacity(0.06)
            Image(systemName: "fork.knife")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.fridjText.opacity(0.25))
        }
    }

    private func resolveAndLoad() async {
        // Re-sync to the CURRENT dish. This view can be REUSED for a different
        // dish (e.g. tapping meal cards in quick succession) — @State survives
        // that reuse, so without this the previous dish's photo lingers. Show
        // this dish's cached image instantly if we have it; otherwise clear any
        // leftover image so a stale one never shows while the new one loads.
        if let url = MealImageCache.shared.url(for: dish),
           let hit = MealImageStore.shared.cached(url) {
            uiImage = hit          // instant loads stay instant
            loadFailed = false
            return
        }
        uiImage = nil
        loadFailed = false

        do {
            let url: URL
            if let cached = MealImageCache.shared.url(for: dish) {
                url = cached
            } else {
                url = try await FrijAPI.mealImage(dish: dish)
                guard !Task.isCancelled else { return }
                MealImageCache.shared.set(url, for: dish)
            }
            let image = try await MealImageStore.shared.load(url)
            // A slow load for a dish we've since navigated away from must not
            // overwrite the current one — the task is cancelled on dish change.
            guard !Task.isCancelled else { return }
            uiImage = image
        } catch {
            guard !Task.isCancelled else { return }
            // A cached URL can die (creator thumbnails on platform CDNs
            // expire). Drop it and re-resolve once — the backend then
            // serves/generates its own image.
            MealImageCache.shared.remove(for: dish)
            if let fresh = try? await FrijAPI.mealImage(dish: dish),
               let image = try? await MealImageStore.shared.load(fresh) {
                guard !Task.isCancelled else { return }
                MealImageCache.shared.set(fresh, for: dish)
                uiImage = image
            } else {
                guard !Task.isCancelled else { return }
                loadFailed = true
            }
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
