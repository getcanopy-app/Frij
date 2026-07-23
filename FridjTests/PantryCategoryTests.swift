//
//  PantryCategoryTests.swift
//  FridjTests
//
//  PantryCategory decides which header a pantry chip sits under. It matches
//  keywords by substring and picks the LONGEST match, which is what resolves
//  the overlaps ("black pepper" is a staple, not produce). Two bugs motivated
//  these tests: a plain substring match missed plurals ("strawberries" does
//  not contain "strawberry"), and some obvious items had no keyword at all.
//

import Testing
@testable import Fridj

struct PantryCategoryTests {

    // MARK: Plurals — the substring match used to miss these entirely

    @Test func pluralBerriesLandInProduce() {
        #expect(PantryCategory.classify("strawberries") == .produce)
        #expect(PantryCategory.classify("blueberries") == .produce)
        #expect(PantryCategory.classify("raspberries") == .produce)
        #expect(PantryCategory.classify("cherries") == .produce)
    }

    @Test func pluralsEndingInEsLandCorrectly() {
        #expect(PantryCategory.classify("tomatoes") == .produce)
        #expect(PantryCategory.classify("potatoes") == .produce)
    }

    @Test func simplePluralsStillWork() {
        #expect(PantryCategory.classify("carrots") == .produce)
        #expect(PantryCategory.classify("grapes") == .produce)
        #expect(PantryCategory.classify("eggs") == .protein)
    }

    // MARK: Keywords that were missing

    @Test func dessertStaplesAreRecognized() {
        #expect(PantryCategory.classify("chocolate") == .staples)
        #expect(PantryCategory.classify("chocolate chips") == .staples)
        #expect(PantryCategory.classify("nutella") == .staples)
        #expect(PantryCategory.classify("jam") == .staples)
    }

    // MARK: Longest-match wins — the overlap rule must survive the plural fix

    @Test func longestKeywordWinsOverShorterOverlap() {
        // "black pepper" contains "pepper" (produce) but must be a staple.
        #expect(PantryCategory.classify("black pepper") == .staples)
        // "eggplant" contains "egg" (protein) but is produce.
        #expect(PantryCategory.classify("eggplant") == .produce)
        // "peanut butter" contains "butter" (dairy) but is a staple.
        #expect(PantryCategory.classify("peanut butter") == .staples)
        // "coffee creamer" contains "cream" (dairy) but "coffee" is longer.
        #expect(PantryCategory.classify("coffee creamer") == .staples)
    }

    // MARK: Fallback

    @Test func unknownItemsFallToOther() {
        #expect(PantryCategory.classify("dragon fruit jelly powder") == .other)
        #expect(PantryCategory.classify("") == .other)
    }

    @Test func realWorldPantryClassifiesSensibly() {
        #expect(PantryCategory.classify("chicken thighs") == .protein)
        #expect(PantryCategory.classify("olive oil") == .staples)
        #expect(PantryCategory.classify("parmesan") == .dairy)
        #expect(PantryCategory.classify("spinach") == .produce)
    }
}
