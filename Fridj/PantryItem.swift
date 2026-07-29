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

    var daysSinceLastSeen: Int {
        Calendar.current.dateComponents([.day], from: lastSeenAt, to: Date()).day ?? 0
    }

    enum FreshnessWarning {
        case none, watch, old, stale
    }

    var freshnessWarning: FreshnessWarning {
        guard source != .default else { return .none }
        // Only things that actually spoil get flagged. Salt, rice, and farofa
        // are immortal — warning about them kills trust in every real warning.
        guard PantryCategory.classify(name).isPerishable else { return .none }
        switch daysSinceLastSeen {
        case 0..<4:  return .none
        case 4..<7:  return .watch
        case 7..<14: return .old
        default:     return .stale
        }
    }
}

// MARK: - Migration-safe decoding
//
// PantryItem is persisted to disk (PantryStore). Synthesized Codable throws
// `keyNotFound` for ANY missing key, and the store's load path turns a throw
// into a full wipe ((try? decode) ?? []) — so adding one non-optional field
// later would silently erase every user's saved pantry.
//
// This decoder reads every field with decodeIfPresent + a fallback, so blobs
// written by an older build (which lack fields added later) still decode.
// Rule when you add a field: add a matching `decodeIfPresent(...) ?? default`
// line below. The compiler enforces it — a new stored property left unset here
// is a build error, never a runtime data-loss surprise.
extension PantryItem {
    private enum CodingKeys: String, CodingKey {
        case id, name, source, firstSeenAt, lastSeenAt
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Date()
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        self.source = try c.decodeIfPresent(Source.self, forKey: .source) ?? .manual
        self.firstSeenAt = try c.decodeIfPresent(Date.self, forKey: .firstSeenAt) ?? now
        self.lastSeenAt = try c.decodeIfPresent(Date.self, forKey: .lastSeenAt) ?? now
    }
}
