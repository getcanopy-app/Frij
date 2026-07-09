//
//  FrijLinks.swift
//  Fridj
//
//  Single source of truth for the app's legal URLs. Surfaced on the paywall
//  (Apple requires functional Terms + Privacy links for auto-renewable
//  subscriptions) and in Profile.
//
//  Live pages hosted on Vercel (frij-legal project). If you later point a
//  custom domain (e.g. frij.app) at that project, update both here.
//

import Foundation

enum FrijLinks {
    static let terms   = URL(string: "https://frij-legal.vercel.app/terms")!
    static let privacy = URL(string: "https://frij-legal.vercel.app/privacy")!
}
