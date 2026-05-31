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
    var household: HouseholdSize?   // optional — empty by default
    var dislikes: String = ""       // e.g. "no cilantro, no mushrooms"

    var isEmpty: Bool {
        diet.isEmpty && household == nil && dislikes.isEmpty
    }
}
