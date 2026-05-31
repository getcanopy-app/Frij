//
//  PantryItem.swift
//  Fridj
//
//  A single thing that lives in the user's pantry.
//  Persisted across app sessions so Frij doesn't forget.
//

import Foundation

struct PantryItem: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String          // lowercase, e.g. "yogurt"
    var addedAt: Date         // when first seen
    var lastSeenAt: Date      // updated every time it's re-confirmed in a scan
    var source: Source

    enum Source: String, Codable {
        case scanned
        case manual
    }

    init(name: String, source: Source, now: Date = Date()) {
        self.id = UUID()
        self.name = name.lowercased().trimmingCharacters(in: .whitespaces)
        self.addedAt = now
        self.lastSeenAt = now
        self.source = source
    }
}
