//
//  PantryItem.swift
//  Fridj
//

import Foundation

struct PantryItem: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case scanned   // detected by /api/scan
        case manual    // user typed it in
        case `default` // pre-loaded on first launch (salt, pepper, olive oil, sugar)
    }

    let id: UUID
    var name: String        // lowercase, normalized
    var source: Source
    var firstSeenAt: Date
    var lastSeenAt: Date

    init(name: String, source: Source = .manual, id: UUID = UUID(), now: Date = Date()) {
        self.id = id
        self.name = name
        self.source = source
        self.firstSeenAt = now
        self.lastSeenAt = now
    }
}
