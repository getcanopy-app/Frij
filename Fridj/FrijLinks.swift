//
//  FrijLinks.swift
//  Fridj
//
//  Single source of truth for the app's legal URLs. Surfaced on the paywall
//  (Apple requires functional Terms + Privacy links for auto-renewable
//  subscriptions) and in Profile.
//
//  Live pages hosted on Vercel (frij-legal project), served via the custom
//  domain hellofrij.com. frij-legal.vercel.app remains as a fallback alias.
//

import Foundation

enum FrijLinks {
    static let terms   = URL(string: "https://hellofrij.com/terms")!
    static let privacy = URL(string: "https://hellofrij.com/privacy")!

    // The live App Store listing (Frij went live 2026-08). id6790869941.
    static let appStore = URL(string: "https://apps.apple.com/app/id6790869941")!

    // Deep link that opens the App Store straight to the "write a review" sheet.
    static let writeReview = URL(string: "https://apps.apple.com/app/id6790869941?action=write-review")!

    // The message that rides along with a share.
    static let shareText = "Frij turns whatever's in your fridge into dinner — snap a photo, get 3 recipes. Cook what you have instead of ordering out."
}
