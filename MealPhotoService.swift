import Foundation

// Fetches AI-generated food photos from the Frij backend (/api/recipe-image).
// The backend generates via OpenAI, caches in Supabase, so first call is slow
// (~10-15s) and every subsequent call for the same dish is instant.
@MainActor
@Observable
final class MealPhotoService {
    static let shared = MealPhotoService()
    private init() {}

    // Accessed directly in view bodies so @Observable tracks changes.
    var urls: [String: URL] = [:]
    private var fetching: Set<String> = []

    func fetch(for name: String) async {
        guard !fetching.contains(name) else { return }
        fetching.insert(name)

        guard let endpoint = URL(string: "\(FrijAPI.baseURL)/api/recipe-image") else { return }

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 90   // generation can take ~15s on first call
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["name": name])

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let imageURL = json["imageURL"] as? String,
              let url = URL(string: imageURL)
        else { return }

        urls[name] = url
    }
}
