import Foundation
import Testing
@testable import Fridj

/// Deleting the app wipes UserDefaults but not the Keychain. These simulate
/// that by clearing UserDefaults and building a fresh UsageStore, which is
/// what a reinstall looks like to the app.
@MainActor
@Suite(.serialized)
struct UsageStoreTests {
    private let keys = ["frij.usage.v1.generationsUsed",
                        "frij.usage.v1.bonusGenerations",
                        "frij.usage.v1.redeemedCode"]

    private func wipeEverything() {
        for k in keys {
            UserDefaults.standard.removeObject(forKey: k)
            KeychainHelper.delete(key: k)
        }
    }

    private func simulateReinstall() {
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
    }

    @Test func freeIdeasUsedSurviveReinstall() {
        wipeEverything()
        // Debug builds default to admin (unlimited, nothing counted). Count
        // like a real user for this test, then put the setting back.
        let adminKey = "frij.usage.v1.isAdmin"
        let savedAdmin = UserDefaults.standard.object(forKey: adminKey)
        UserDefaults.standard.set(false, forKey: adminKey)
        defer {
            wipeEverything()
            UserDefaults.standard.set(savedAdmin, forKey: adminKey)
        }

        let before = UsageStore()
        before.recordGeneration()
        before.recordGeneration()
        #expect(before.generationsUsed == 2)

        simulateReinstall()
        #expect(UsageStore().generationsUsed == 2)
    }

    @Test func creatorCodeCantBeRedeemedAgainAfterReinstall() {
        wipeEverything()
        defer { wipeEverything() }

        #expect(UsageStore().applyCreatorBonus(5, code: "TESTCODE"))

        simulateReinstall()
        let after = UsageStore()
        #expect(after.bonusGenerations == 5)
        #expect(after.hasRedeemedCode)
        #expect(after.applyCreatorBonus(5, code: "TESTCODE") == false)
    }

    @Test func countsFromOlderBuildsCarryOver() {
        wipeEverything()
        defer { wipeEverything() }

        // An existing user's count, stored where older builds kept it.
        UserDefaults.standard.set(3, forKey: "frij.usage.v1.generationsUsed")
        #expect(UsageStore().generationsUsed == 3)
    }
}
