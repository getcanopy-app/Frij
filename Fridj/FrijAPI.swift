//
//  FrijAPI.swift
//  Fridj
//
//  Created by Gabriel Nejad on 5/28/26.
//
//  The networking layer — the Swift mirror of the curl commands.
//  Talks to the Frij backend (which holds the OpenAI key server-side).
//  The app NEVER contains an API key; it only knows this URL.
//

import Foundation
import UIKit

enum FrijAPIError: LocalizedError {
    case badResponse(String)
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .badResponse(let detail): return detail
        case .imageEncodingFailed:     return "Couldn't prepare the photo. Try another shot."
        }
    }
}

enum FrijAPI {
    // The live backend. To test against your laptop instead, swap to
    // "http://localhost:3001" (and run `vercel dev`).
    static let baseURL = "https://frij-backend.vercel.app"

    // MARK: Scan — fridge photo -> ingredients with confidence
    static func scan(image: UIImage) async throws -> [DetectedItem] {
        // Convert + downscale on-device before upload (handles HEIC, shrinks size).
        guard let jpegBase64 = ImagePrep.jpegBase64(from: image) else {
            throw FrijAPIError.imageEncodingFailed
        }

        let body: [String: Any] = [
            "image": jpegBase64,
            "mediaType": "image/jpeg"
        ]
        let data = try await post("/api/scan", body: body)
        let decoded = try JSONDecoder().decode(ScanResponse.self, from: data)
        return decoded.items
    }

    // MARK: Recipes — ingredients -> 3 dinners
    static func recipes(ingredients: [String], diet: String?) async throws -> [Recipe] {
        var body: [String: Any] = ["ingredients": ingredients]
        if let diet, !diet.isEmpty { body["diet"] = diet }

        let data = try await post("/api/recipes", body: body)
        let decoded = try JSONDecoder().decode(RecipeResponse.self, from: data)
        return decoded.recipes
    }

    // MARK: Shared POST helper
    private static func post(_ path: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw FrijAPIError.badResponse("Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60 // model calls can take a few seconds

        let (data, response) = try await URLSession.shared.data(for: req)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            // Try to surface the backend's {"error":...,"detail":...} message.
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let detail = (obj["detail"] as? String) ?? (obj["error"] as? String) ?? "Server error \(http.statusCode)"
                throw FrijAPIError.badResponse(detail)
            }
            throw FrijAPIError.badResponse("Server error \(http.statusCode)")
        }
        return data
    }
}
