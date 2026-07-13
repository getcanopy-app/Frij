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
}
