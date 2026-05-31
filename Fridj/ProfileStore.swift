//
//  ProfileStore.swift
//  Fridj
//

import Foundation
import Observation

@Observable
final class ProfileStore {
    static let shared = ProfileStore()

    var profile: Profile {
        didSet { save() }
    }

    private let storageKey = "frij.profile.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.profile = Self.load(from: defaults, key: storageKey)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(profile)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("ProfileStore save failed:", error)
        }
    }

    private static func load(from defaults: UserDefaults, key: String) -> Profile {
        guard let data = defaults.data(forKey: key) else { return Profile() }
        return (try? JSONDecoder().decode(Profile.self, from: data)) ?? Profile()
    }
}
