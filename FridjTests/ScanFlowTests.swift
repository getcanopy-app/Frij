//
//  ScanFlowTests.swift
//  FridjTests
//
//  Characterization tests — these assert what the scan flow does TODAY, so a
//  red test flags any behavior change during the upcoming refactor. They are
//  NOT a spec of ideal behavior; where today's behavior is quirky (see the
//  asymmetries in cancel/reset/scanFailed) the test locks in the quirk on
//  purpose. Change a test only when you INTEND to change behavior.
//

import Testing
import Foundation
@testable import Fridj

// MARK: - ScanFlowModel: the entry → scanning → reviewing state machine

/// A one-shot async gate: `wait()` suspends until `fire()` is called. Lets a test
/// hand control back and forth deterministically — used here to place a cancel in
/// the exact window between runScan's outer guard and its in-apply re-check.
@MainActor
private final class OneShotGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var fired = false
    func wait() async {
        if fired { return }
        await withCheckedContinuation { continuation = $0 }
    }
    func fire() {
        fired = true
        continuation?.resume()
        continuation = nil
    }
}

@Suite("ScanFlowModel transitions")
@MainActor
struct ScanFlowModelTests {

    private func item(_ name: String, _ confidence: Confidence = .high) -> DetectedItem {
        DetectedItem(item: name, confidence: confidence)
    }

    @Test("Fresh model starts in entry with nothing captured")
    func initialState() {
        let m = ScanFlowModel()
        #expect(m.phase == .entry)
        #expect(m.hasCapture == false)
        #expect(m.detected.isEmpty)
        #expect(m.lastError == nil)
    }

    @Test("beginScan → scanning, capture present")
    func beginScanEntersScanning() {
        let m = ScanFlowModel()
        m.beginScan()
        #expect(m.phase == .scanning)
        #expect(m.hasCapture == true)
    }

    @Test("scanSucceeded → reviewing, detected populated, capture STAYS present")
    func scanSucceededEntersReviewing() {
        let m = ScanFlowModel()
        m.beginScan()
        let found = [item("tomato"), item("milk", .low)]
        m.scanSucceeded(found)
        #expect(m.phase == .reviewing)
        #expect(m.detected == found)
        // Photo must stay behind the found panel — no flicker on handoff.
        #expect(m.hasCapture == true)
        #expect(m.lastError == nil)
    }

    @Test("scanFailed → entry, capture dropped, error surfaced, detected untouched")
    func scanFailedReturnsToEntry() {
        let m = ScanFlowModel()
        m.beginScan()
        m.scanSucceeded([item("tomato")])   // seed detected to prove it survives
        m.scanFailed("network died")
        #expect(m.phase == .entry)
        #expect(m.hasCapture == false)
        #expect(m.lastError == "network died")
        // Characterizes today's catch block: it does NOT clear scanDetectedItems.
        #expect(m.detected == [item("tomato")])
    }

    @Test("cancel → entry, capture dropped, detected cleared, error left as-is")
    func cancelClearsToEntry() {
        let m = ScanFlowModel()
        m.beginScan()
        m.scanSucceeded([item("tomato")])
        m.lastError = "stale error"
        m.cancel()
        #expect(m.phase == .entry)
        #expect(m.hasCapture == false)
        #expect(m.detected.isEmpty)
        // cancelScan doesn't touch scanError — the stale error persists.
        #expect(m.lastError == "stale error")
    }

    @Test("cancel mid-scan → entry, captured photo dropped, detected cleared")
    func cancelMidScanReturnsToEntry() {
        let m = ScanFlowModel()
        m.beginScan()                      // in-flight scan: .scanning with a capture
        #expect(m.phase == .scanning)      // precondition: we are mid-scan
        #expect(m.hasCapture == true)

        m.cancel()                         // user taps Cancel during "Hold still…"

        #expect(m.phase == .entry)         // returns to entry
        #expect(m.hasCapture == false)     // captured photo dropped
        #expect(m.detected.isEmpty)        // detected items cleared
        // NOTE: restoring the tab bar (session.hidesTabBar = false) is NOT part
        // of this path — it's a ScanSession flag reset by the View's cancelScan(),
        // outside ScanFlowModel, so a model unit test can't assert it. See header.
    }

    @Test("reset → entry, capture dropped, but detected AND error survive")
    func resetReturnsToEntry() {
        let m = ScanFlowModel()
        m.beginScan()
        m.scanSucceeded([item("tomato")])
        m.lastError = "some error"
        m.reset()
        #expect(m.phase == .entry)
        #expect(m.hasCapture == false)
        // resetToEntry leaves scanDetectedItems and scanError untouched today.
        #expect(m.detected == [item("tomato")])
        #expect(m.lastError == "some error")
    }

    // MARK: The cancel / late-result race (runScan's Task.isCancelled guard)
    //
    // The in-flight scan runs as a Task the coordinator holds in `scanTask`.
    // cancelScan() runs on the MainActor and does scanTask?.cancel() + flow.cancel().
    // The ONLY thing that stops a scan which finishes AFTER that cancel from
    // applying its result is runScan's `if Task.isCancelled { return }` guard,
    // checked right after `await FrijAPI.scan` and before the result is written
    // into the model/session. These characterize that seam.

    @Test("A scan that finishes after cancel is dropped by the Task.isCancelled guard")
    func lateResultAfterCancelIsDropped() async {
        let m = ScanFlowModel()
        m.beginScan()                      // scan in flight: .scanning with a capture
        let found = [item("tomato")]

        // Mirror runScan: the network result is applied inside a Task, gated by
        // the SAME `if Task.isCancelled { return }` guard the coordinator uses.
        // On the serial MainActor this body can't start until we await below, so
        // the cancels are guaranteed to land first — deterministic, no sleep.
        let scan = Task { @MainActor in
            if Task.isCancelled { return }     // ← runScan's guard, verbatim
            m.scanSucceeded(found)             // the late result we must NOT apply
        }
        scan.cancel()                      // coordinator: scanTask?.cancel()
        m.cancel()                         // coordinator: flow.cancel()
        await scan.value

        // Guard held: the finished-late scan never resurrected the flow.
        #expect(m.phase == .entry)
        #expect(m.hasCapture == false)
        #expect(m.detected.isEmpty)
    }

    @Test("The model does NOT self-guard a late result — the coordinator's guard is load-bearing")
    func modelDoesNotSelfGuardLateResult() {
        let m = ScanFlowModel()
        m.beginScan()
        m.cancel()                         // user cancelled

        // If the coordinator's Task.isCancelled guard were ever removed, a late
        // result would reach the model as a bare scanSucceeded — and the model,
        // having no memory of the cancel, WOULD go to reviewing. Pinning this
        // documents WHY the guard must stay: the safety lives in the coordinator,
        // not the model.
        m.scanSucceeded([item("tomato")])
        #expect(m.phase == .reviewing)
        #expect(m.detected == [item("tomato")])
    }

    @Test("Inner re-check: a scan cancelled AFTER the outer guard still drops at apply time")
    func resultCancelledDuringApplyIsDropped() async {
        let m = ScanFlowModel()
        m.beginScan()
        let found = [item("tomato")]

        // Place the cancel deterministically in the window BETWEEN runScan's outer
        // `if Task.isCancelled` guard and the re-check at the top of its
        // MainActor.run apply block — no sleeps, no yield races.
        let outerPassed = OneShotGate()
        let proceed = OneShotGate()

        let scan = Task { @MainActor in
            if Task.isCancelled { return }   // outer guard — sees NOT cancelled
            outerPassed.fire()               // we're now past it
            await proceed.wait()             // park in the outer→apply window
            if Task.isCancelled { return }   // ← Step 3 re-check inside the apply
            m.scanSucceeded(found)           // must NOT run
        }

        await outerPassed.wait()   // outer guard has run and passed
        scan.cancel()              // cancelScan: scanTask?.cancel()
        m.cancel()                 // cancelScan: flow.cancel() → model back to entry
        proceed.fire()             // now let the apply step evaluate its re-check
        await scan.value

        // Re-check caught the late cancel: the result never resurrected the flow.
        #expect(m.phase == .entry)
        #expect(m.hasCapture == false)
        #expect(m.detected.isEmpty)
    }
}

// MARK: - PantryStore.mergeScan: merge detected items into the pantry

@Suite("PantryStore.mergeScan")
@MainActor
struct PantryMergeScanTests {

    // Build a PantryStore backed by a throwaway UserDefaults suite, with default
    // seeding suppressed so we start from an empty pantry. The seed flag key is
    // duplicated from PantryStore (private there); if that key changes, update here.
    private func makeEmptyStore(_ suite: String) -> PantryStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(true, forKey: "frij.pantry.didSeedDefaults.v1")  // skip default seeding
        return PantryStore(defaults: defaults)
    }

    private func item(_ name: String, _ confidence: Confidence = .high) -> DetectedItem {
        DetectedItem(item: name, confidence: confidence)
    }

    @Test("Adds new items regardless of confidence; returns the newly-added names")
    func addsNewItems() {
        let store = makeEmptyStore("test.merge.add")
        let added = store.mergeScan([item("tomato", .high), item("milk", .low)])
        #expect(Set(store.allNames) == ["tomato", "milk"])
        #expect(Set(added) == ["tomato", "milk"])
    }

    @Test("Lowercases and trims item names before storing")
    func lowercasesAndTrims() {
        let store = makeEmptyStore("test.merge.trim")
        let added = store.mergeScan([item("  Tomato ")])
        #expect(store.allNames == ["tomato"])
        #expect(added == ["tomato"])
    }

    @Test("Existing item is not duplicated and not reported as newly added")
    func dedupsExisting() {
        let store = makeEmptyStore("test.merge.dedup")
        _ = store.mergeScan([item("tomato")])
        let added = store.mergeScan([item("Tomato")])   // same item, different case
        #expect(store.allNames == ["tomato"])
        #expect(added.isEmpty)
    }

    @Test("Blank / whitespace-only names are skipped")
    func skipsEmpty() {
        let store = makeEmptyStore("test.merge.empty")
        let added = store.mergeScan([item("   ")])
        #expect(store.allNames.isEmpty)
        #expect(added.isEmpty)
    }
}
