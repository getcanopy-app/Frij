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
    static func recipes(ingredients: [String], extraDiet: String? = nil) async throws -> [Recipe] {
        let profile = ProfileStore.shared.profile
        var body: [String: Any] = ["ingredients": ingredients]

        // Combine profile.diet with the optional per-call diet hint.
        let combinedDiet = [profile.diet, extraDiet]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        if !combinedDiet.isEmpty { body["diet"] = combinedDiet }

        if !profile.dislikes.trimmingCharacters(in: .whitespaces).isEmpty {
            body["dislikes"] = profile.dislikes
        }
        if let household = profile.household {
            body["household"] = household.rawValue
        }

        let data = try await post("/api/recipes", body: body)
        return try JSONDecoder().decode(RecipeResponse.self, from: data).recipes
    }

    static func validate(name: String) async throws -> ValidationResult {
        let body: [String: Any] = ["name": name]
        let data = try await post("/api/validate", body: body)
        return try JSONDecoder().decode(ValidationResult.self, from: data)
    }

    private static func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw FrijAPIError.badResponse("Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
