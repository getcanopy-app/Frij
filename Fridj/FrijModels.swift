//
//  FrijModels.swift
//  Fridj
//
//  Created by Gabriel Nejad on 5/28/26.
//
//  Data models matching the Frij backend contract.
//

import Foundation

// MARK: - Scan (photo -> ingredients)

enum Confidence: String, Codable {
    case high, medium, low
}

struct BoundingBox: Codable, Hashable {
    let x: Double
    let y: Double
    let w: Double
    let h: Double

    var centerX: Double { x + w / 2 }
    var centerY: Double { y + h / 2 }
}

struct DetectedItem: Codable, Identifiable, Hashable {
    var id: String { item }
    let item: String
    let confidence: Confidence
    var box: BoundingBox? = nil

    init(item: String, confidence: Confidence, box: BoundingBox? = nil) {
        self.item = item
        self.confidence = confidence
        self.box = box
    }
}

struct ScanResponse: Codable {
    let version: Int
    let items: [DetectedItem]
}

// MARK: - Recipes (ingredients -> 3 dinners)

struct Recipe: Codable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let cookTime: String
    let uses: [String]
    let needs: [String]
    let steps: [String]
    // A one-line "Because you…" note explaining why this dish fits THIS user,
    // returned by the backend only when a taste profile was sent. Optional so
    // desserts, the no-profile case, and older saved favorites all decode fine.
    let reason: String?
    // Where an imported meal came from ("Instagram", "TikTok", "YouTube"…).
    // nil = generated in the app. Optional for the same migration reasons.
    let origin: String?

    init(name: String, cookTime: String, uses: [String], needs: [String], steps: [String],
         reason: String? = nil, origin: String? = nil) {
        self.name = name
        self.cookTime = cookTime
        self.uses = uses
        self.needs = needs
        self.steps = steps
        self.reason = reason
        self.origin = origin
    }

    // Migration-safe decoding. Recipe is persisted to disk (FavoritesStore) as
    // the whole struct, so a saved favorite written by an older build must keep
    // decoding after we add fields. Every field falls back to a default when its
    // key is absent instead of throwing (which the store turns into a full wipe).
    // Rule: when you add a field, add a `decodeIfPresent(...) ?? default` line.
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.cookTime = try c.decodeIfPresent(String.self, forKey: .cookTime) ?? ""
        self.uses = try c.decodeIfPresent([String].self, forKey: .uses) ?? []
        self.needs = try c.decodeIfPresent([String].self, forKey: .needs) ?? []
        self.steps = try c.decodeIfPresent([String].self, forKey: .steps) ?? []
        self.reason = try c.decodeIfPresent(String.self, forKey: .reason)
        self.origin = try c.decodeIfPresent(String.self, forKey: .origin)
    }
}

struct RecipeResponse: Codable {
    let version: Int
    let recipes: [Recipe]
}
