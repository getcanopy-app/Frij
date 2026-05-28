//
//  FrijModels.swift
//  Fridj
//
//  Created by Gabriel Nejad on 5/28/26.
//
//  Data models matching the Frij backend contract.
//  These decode exactly what https://frij-backend.vercel.app returns.
//

import Foundation

// MARK: - Scan (photo -> ingredients)

enum Confidence: String, Codable {
    case high, medium, low
}

struct DetectedItem: Codable, Identifiable, Hashable {
    var id: String { item }
    let item: String
    let confidence: Confidence
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
}

struct RecipeResponse: Codable {
    let version: Int
    let recipes: [Recipe]
}
