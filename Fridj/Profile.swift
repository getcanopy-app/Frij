//
//  Profile.swift
//  Fridj
//
//  Persistent user profile: diet, household size, dislikes.
//  Used to personalize recipe suggestions.
//

import Foundation

enum HouseholdSize: Int, Codable, CaseIterable, Identifiable {
    case one = 1
    case two = 2
    case smallGroup = 4    // 3-4
    case largeGroup = 6    // 5+

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .one: return "Just me"
        case .two: return "Two of us"
        case .smallGroup: return "3–4"
        case .largeGroup: return "5+"
        }
    }
}

struct Profile: Codable, Equatable {
    var diet: String = ""           // e.g. "high protein, no pork"
    var cuisine: String = ""        // e.g. "Persian, Italian" — a soft lean, not a rule
    var household: HouseholdSize?   // optional — empty by default
    var dislikes: String = ""       // e.g. "no cilantro, no mushrooms"

    init(diet: String = "", cuisine: String = "", household: HouseholdSize? = nil, dislikes: String = "") {
        self.diet = diet
        self.cuisine = cuisine
        self.household = household
        self.dislikes = dislikes
    }

    var isEmpty: Bool {
        diet.trimmingCharacters(in: .whitespaces).isEmpty &&
        cuisine.trimmingCharacters(in: .whitespaces).isEmpty &&
        household == nil &&
        dislikes.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Migration-safe decoding. Profile is persisted (ProfileStore); a stored
    // property's default is NOT applied by synthesized Codable when its key is
    // missing — it throws, which the store turns into a reset to a blank
    // profile. Decode each field with a fallback so old/partial blobs survive.
    // Rule: when you add a field, add a `decodeIfPresent(...) ?? default` line.
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.diet = try c.decodeIfPresent(String.self, forKey: .diet) ?? ""
        self.cuisine = try c.decodeIfPresent(String.self, forKey: .cuisine) ?? ""
        self.household = try c.decodeIfPresent(HouseholdSize.self, forKey: .household)
        self.dislikes = try c.decodeIfPresent(String.self, forKey: .dislikes) ?? ""
    }
}
