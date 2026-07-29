//
//  FrijAPI.swift
//  Fridj
//

import Foundation
import UIKit

enum FrijAPIError: LocalizedError {
    case badResponse(String)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .badResponse(let detail): return detail
        case .imageEncodingFailed: return "Couldn't prepare the photo. Try another shot."
        }
    }
}

struct ValidationResult: Codable {
    let valid: Bool
    let normalized: String?
    let reason: String?
}

// Stable per-device identity stored in Keychain — survives reinstalls.
// Used to enforce the free tier server-side so deleting the app doesn't reset the count.
enum DeviceID {
    private static let key = "frij.deviceID"

    static var current: String {
        if let existing = KeychainHelper.load(key: key) { return existing }
        let fresh = UUID().uuidString
        KeychainHelper.save(key: key, value: fresh)
        return fresh
    }
}

enum FrijAPI {
    static let baseURL = "https://frij-backend.vercel.app"

    static func scan(image: UIImage) async throws -> [DetectedItem] {
        guard let jpegBase64 = ImagePrep.jpegBase64(from: image) else {
            throw FrijAPIError.imageEncodingFailed
        }
        let body: [String: Any] = ["image": jpegBase64, "mediaType": "image/jpeg"]
        let data = try await post("/api/scan", body: body)
        return try JSONDecoder().decode(ScanResponse.self, from: data).items
    }

    /// Recipes — pulls profile automatically so callers don't have to thread it through.
    static func recipes(ingredients: [String], extraDiet: String? = nil,
                        mode: String = "dinner", prioritize: [String] = []) async throws -> [Recipe] {
        let profile = ProfileStore.shared.profile
        var body: [String: Any] = ["ingredients": ingredients]
        // Dinner is the unmarked default; any detour mode rides along.
        if mode != "dinner" { body["mode"] = mode }
        // "Use it up" — items about to spoil the backend should build around.
        if !prioritize.isEmpty { body["prioritize"] = prioritize }

        // Combine profile.diet with the optional per-call diet hint.
        let combinedDiet = [profile.diet, extraDiet]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if !combinedDiet.isEmpty { body["diet"] = combinedDiet }

        if !profile.dislikes.trimmingCharacters(in: .whitespaces).isEmpty {
            body["dislikes"] = profile.dislikes
        }
        // Cuisine is a soft lean handled server-side; only send it when set.
        let cuisine = profile.cuisine.trimmingCharacters(in: .whitespaces)
        if !cuisine.isEmpty {
            body["cuisine"] = cuisine
        }
        if let household = profile.household {
            body["household"] = household.rawValue
        }
        // Taste profile — a soft lean derived from what the user has saved, so
        // the picks (and the "Because you…" reasons) get personal over time.
        // Dinner-only: the dessert and snack briefs are their own thing.
        if mode == "dinner",
           let taste = TasteProfile.brief(
               favorites: FavoritesStore.shared.recipes,
               cooked: TasteSignalsStore.shared.cooked,
               disliked: TasteSignalsStore.shared.disliked,
               quizPicks: TasteSignalsStore.shared.quizPicks) {
            body["tasteProfile"] = taste
        }

        // Don't re-serve dishes the user just saw — this is what makes "more
        // options" actually give new ideas. Saved dishes are excluded too:
        // they're already secured in Saved, so re-suggesting one is worthless
        // (and the taste lean would otherwise pull the model back toward it).
        var excludeSeen = Set<String>()
        var exclude: [String] = []
        for name in RecipeHistoryStore.shared.recentNames(limit: 12) + FavoritesStore.shared.recipes.map(\.name) {
            let key = name.lowercased()
            guard !key.isEmpty, !excludeSeen.contains(key) else { continue }
            excludeSeen.insert(key)
            exclude.append(name)
            if exclude.count >= 20 { break }
        }
        if !exclude.isEmpty { body["exclude"] = exclude }

        let data = try await post("/api/recipes", body: body)
        return try JSONDecoder().decode(RecipeResponse.self, from: data).recipes
    }

    static func mealImage(dish: String) async throws -> URL {
        var req = URLRequest(url: URL(string: baseURL + "/api/recipe-image")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-ID")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: ["name": dish])
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let str = json["imageURL"] as? String,
              let url = URL(string: str)
        else { throw FrijAPIError.badResponse("No imageURL in response") }
        return url
    }

    static func validate(name: String) async throws -> ValidationResult {
        let body: [String: Any] = ["name": name]
        let data = try await post("/api/validate", body: body)
        return try JSONDecoder().decode(ValidationResult.self, from: data)
    }

    /// A shared TikTok/Instagram/YouTube link into a structured recipe.
    /// Backend reads the post's PUBLIC caption/metadata (no account linking —
    /// platforms expose no saved-posts API to anyone) and either extracts the
    /// recipe or reconstructs the named dish. Throws with a friendly message
    /// for private posts, login walls, and non-food links.
    /// Accepts either a link OR pasted recipe/caption text — the text path is
    /// the escape hatch when Instagram walls off a post.
    static func importRecipe(_ input: String) async throws -> Recipe {
        struct Resp: Decodable { let recipe: Recipe; let imageURL: String? }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = trimmed.lowercased().hasPrefix("http")
            ? ["url": trimmed] : ["text": trimmed]
        let data = try await post("/api/import-recipe", body: body)
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        // Show the creator's OWN thumbnail, not an AI reimagining of a dish the
        // user just watched: seeding the cache makes every MealImageView for
        // this dish render it instantly. If the CDN link later dies,
        // MealImageView drops it and falls back to generation.
        if let s = resp.imageURL, let url = URL(string: s) {
            MealImageCache.shared.set(url, for: resp.recipe.name)
        }
        // Stamp where it came from so the UI can tell imported meals from
        // generated ones forever after.
        let d = resp.recipe
        let stamped = Recipe(name: d.name, cookTime: d.cookTime, uses: d.uses,
                             needs: d.needs, steps: d.steps, reason: d.reason,
                             origin: importOrigin(from: trimmed))
        return await crossCheckPantry(stamped)
    }

    /// Platform name from the shared/pasted input — nil for plain text and
    /// for anything generated in-app.
    private static func importOrigin(from input: String) -> String? {
        guard let url = URL(string: input), let host = url.host?.lowercased() else { return nil }
        if host.contains("tiktok") { return "TikTok" }
        if host.contains("instagram") { return "Instagram" }
        if host.contains("youtu") { return "YouTube" }
        if host.contains("pinterest") { return "Pinterest" }
        return "Web"
    }

    /// The Frij twist on import — the part a recipe binder can't do. Partition
    /// the imported ingredient list against the live pantry (PantryMatch) into
    /// the app's existing semantics: `uses` = already in your fridge, `needs` =
    /// shopping list. The detail sheet re-derives this live on every render;
    /// the stored split is just a sensible starting point.
    @MainActor
    private static func crossCheckPantry(_ recipe: Recipe) -> Recipe {
        let split = PantryMatch.partition(recipe.needs)
        guard !split.have.isEmpty else { return recipe }
        return Recipe(name: recipe.name, cookTime: recipe.cookTime,
                      uses: split.have,
                      needs: split.need,
                      steps: recipe.steps, reason: recipe.reason,
                      origin: recipe.origin)
    }

    /// One messy phrase — typed or dictated — into a clean, normalized list.
    static func parseIngredients(text: String) async throws -> [String] {
        struct Resp: Decodable { let items: [String] }
        let data = try await post("/api/parse-ingredients", body: ["text": text])
        return (try? JSONDecoder().decode(Resp.self, from: data))?.items ?? []
    }

    private static func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw FrijAPIError.badResponse("Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-ID")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let detail = (obj["detail"] as? String) ?? (obj["error"] as? String) ?? "Server error \(http.statusCode)"
                throw FrijAPIError.badResponse(detail)
            }
            throw FrijAPIError.badResponse("Server error \(http.statusCode)")
        }
        return data
    }
}
