//
//  FrijLinks.swift
//  Fridj
//
//  Single source of truth for the app's legal URLs. Surfaced on the paywall
//  (Apple requires functional Terms + Privacy links for auto-renewable
//  subscriptions) and in Profile.
//
//  ⚠️ PLACEHOLDERS — swap both for the real hosted pages before App Store
//  submission. This is the ONLY place they need to change.
//

import Foundation

enum FrijLinks {
    static let terms   = URL(string: "https://frij.app/terms")!
    static let privacy = URL(string: "https://frij.app/privacy")!
}
