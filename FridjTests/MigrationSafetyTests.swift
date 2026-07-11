//
//  MigrationSafetyTests.swift
//  FridjTests
//
//  Regression guard for Codable migration safety. The persisted models
//  (PantryItem, Recipe, Profile, GroceryItem) decode every field with a
//  fallback so data saved by an OLDER build — which lacks any field added
//  later — still loads instead of being silently wiped.
//
//  Each test below feeds a model a JSON blob that OMITS fields the current
//  model has. That is exactly the shape old saved data takes the moment a new
//  field is added: the key isn't there yet. Under synthesized Codable these
//  would throw `keyNotFound`, and the stores' `(try? decode) ?? default` would
//  turn the throw into a full wipe — so every #expect here fails on the old
//  behavior and passes only because the custom decoders tolerate missing keys.
//
//  When you add a field to one of these models, add its `decodeIfPresent`
//  line to that model's decoder and, ideally, a case here proving old data
//  without the field still survives.
//

import Testing
import Foundation
@testable import Fridj

@Suite("Codable migration safety")
struct MigrationSafetyTests {

    private let decoder = JSONDecoder()
    private func data(_ json: String) -> Data { Data(json.utf8) }

    // MARK: PantryItem

    @Test("PantryItem: a blob missing every field except name still decodes")
    func pantryItemSurvivesMissingFields() throws {
        // Simulates saved data from a build that predates source + the timestamps.
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","name":"eggs"}"#
        let item = try decoder.decode(PantryItem.self, from: data(json))
        #expect(item.name == "eggs")
        #expect(item.source == .manual)          // defaulted, not thrown
        #expect(item.id == UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
    }

    @Test("PantryItem array: legacy elements are NOT wiped — all survive")
    func pantryArrayNotWipedByLegacyElements() throws {
        let json = #"""
        [{"id":"11111111-1111-1111-1111-111111111111","name":"eggs"},
         {"id":"22222222-2222-2222-2222-222222222222","name":"milk","source":"scanned"}]
        """#
        let items = try decoder.decode([PantryItem].self, from: data(json))
        #expect(items.count == 2)
        #expect(items.map(\.name) == ["eggs", "milk"])
    }

    // MARK: Recipe (persisted whole in FavoritesStore)

    @Test("Recipe: a blob missing the list fields decodes with empty lists")
    func recipeSurvivesMissingFields() throws {
        let json = #"{"name":"Tacos","cookTime":"20 min"}"#
        let recipe = try decoder.decode(Recipe.self, from: data(json))
        #expect(recipe.name == "Tacos")
        #expect(recipe.cookTime == "20 min")
        #expect(recipe.uses.isEmpty)
        #expect(recipe.needs.isEmpty)
        #expect(recipe.steps.isEmpty)
    }

    // MARK: Profile

    @Test("Profile: a blob with only diet decodes, other fields default")
    func profileSurvivesMissingFields() throws {
        let json = #"{"diet":"vegan"}"#
        let profile = try decoder.decode(Profile.self, from: data(json))
        #expect(profile.diet == "vegan")
        #expect(profile.dislikes == "")
        #expect(profile.household == nil)
    }

    // MARK: GroceryItem

    @Test("GroceryItem: a blob missing isChecked defaults to false")
    func groceryItemSurvivesMissingFields() throws {
        let json = #"{"id":"33333333-3333-3333-3333-333333333333","name":"bread"}"#
        let item = try decoder.decode(GroceryItem.self, from: data(json))
        #expect(item.name == "bread")
        #expect(item.isChecked == false)
    }

    // MARK: End-to-end through the real store load path

    @Test("PantryStore loads a legacy blob through its real load path (no wipe)")
    @MainActor
    func pantryStoreLoadsLegacyBlobEndToEnd() {
        let suite = "test.migration.pantry"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "frij.pantry.didSeedDefaults.v1")  // suppress seeding

        // Data written by an older build: no source, no timestamps.
        let legacy = #"""
        [{"id":"11111111-1111-1111-1111-111111111111","name":"eggs"},
         {"id":"22222222-2222-2222-2222-222222222222","name":"milk"}]
        """#
        defaults.set(data(legacy), forKey: "frij.pantry.v1")

        let store = PantryStore(defaults: defaults)
        // Old behavior: decode throws on the missing keys → items == [] (wiped).
        #expect(store.allNames == ["eggs", "milk"])

        defaults.removePersistentDomain(forName: suite)
    }
}
