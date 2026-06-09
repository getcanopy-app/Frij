import Foundation

// Fetches food photos from TheMealDB (free, no API key).
// Searches by recipe name, caches results so each name is only fetched once.
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

        // Use first 3 words of the name for a broader search match.
        let query = name
            .components(separatedBy: .whitespaces)
            .prefix(3)
            .joined(separator: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        guard let endpoint = URL(string: "https://www.themealdb.com/api/json/v1/1/search.php?s=\(query)"),
              let (data, _) = try? await URLSession.shared.data(from: endpoint),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let meals = json["meals"] as? [[String: Any]],
              let first = meals.first,
              let thumb = first["strMealThumb"] as? String,
              let url = URL(string: thumb)
        else { return }

        urls[name] = url
    }
}
