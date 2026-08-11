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
                        mode: String = "dinner", prioritize: [String] = [],
                        anchored: Bool = false, speed: String = "any") async throws -> [Recipe] {
        let profile = ProfileStore.shared.profile
        var body: [String: Any] = ["ingredients": ingredients]
        // Dinner is the unmarked default; any detour mode rides along.
        if mode != "dinner" { body["mode"] = mode }
        // Anchored = the user hand-picked these items, so build every dish
        // around them instead of diversifying across three proteins.
        if anchored { body["anchored"] = true }
        // Only send when the user asked for fast — "any" is the no-op default.
        if speed == "quick" { body["speed"] = "quick" }
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
        // Stamp the generation mode so surfaces like "Pair it with" know a
        // smoothie from a dinner forever after.
        return try JSONDecoder().decode(RecipeResponse.self, from: data).recipes.map {
            Recipe(name: $0.name, cookTime: $0.cookTime, uses: $0.uses, needs: $0.needs,
                   steps: $0.steps, reason: $0.reason, origin: $0.origin, mode: mode)
        }
    }

    /// Shared app secret — the backend rejects requests without it. This is
    /// abuse deterrence (the binary necessarily contains it), not cryptography.
    private static let appKey = "frij_f0062d3aff5c479d2f9b44c5b12cb24eb0ed8fee"

    static func mealImage(dish: String) async throws -> URL {
        var req = URLRequest(url: URL(string: baseURL + "/api/recipe-image")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-ID")
        req.setValue(appKey, forHTTPHeaderField: "X-Frij-Key")
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
    /// A post can hold several dishes (meal-prep videos). Returns every recipe
    /// the post yielded — one for a normal post, several for "3 lunches this
    /// week" — so the caller can let the user choose.
    static func importRecipes(_ input: String) async throws -> [Recipe] {
        struct Resp: Decodable {
            let recipe: Recipe
            let recipes: [Recipe]?
            let imageURL: String?
        }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any] = trimmed.lowercased().hasPrefix("http")
            ? ["url": trimmed] : ["text": trimmed]
        let data = try await post("/api/import-recipe", body: body)
        let resp = try JSONDecoder().decode(Resp.self, from: data)
        // Show the creator's OWN thumbnail, not an AI reimagining of a dish the
        // user just watched: seeding the cache makes every MealImageView for
        // this dish render it instantly. If the CDN link later dies,
        // MealImageView drops it and falls back to generation. The backend
        // withholds the URL when it's too low-res to look good, so an absent
        // one here means "generate a better photo", not "no photo".
        // Only the FIRST dish gets it — one thumbnail can't depict five meals.
        let found = resp.recipes?.isEmpty == false ? resp.recipes! : [resp.recipe]
        if let s = resp.imageURL, let url = URL(string: s), let first = found.first {
            MealImageCache.shared.set(url, for: first.name)
        }
        // Stamp where it came from so the UI can tell imported meals from
        // generated ones forever after.
        let origin = importOrigin(from: trimmed)
        var out: [Recipe] = []
        for d in found {
            let stamped = Recipe(name: d.name, cookTime: d.cookTime, uses: d.uses,
                                 needs: d.needs, steps: d.steps, reason: d.reason,
                                 origin: origin)
            out.append(await crossCheckPantry(stamped))
        }
        return out
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

    /// Fire-and-forget analytics event (subscribe, first_open, …). Best-effort:
    /// never throws, never blocks a real flow — a dropped event isn't worth an
    /// error to the user.
    static func reportEvent(_ type: String, props: [String: Any] = [:]) {
        Task {
            var body: [String: Any] = props
            body["type"] = type
            _ = try? await post("/api/event", body: body)
        }
    }

    private static func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw FrijAPIError.badResponse("Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(DeviceID.current, forHTTPHeaderField: "X-Device-ID")
        req.setValue(appKey, forHTTPHeaderField: "X-Frij-Key")
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
