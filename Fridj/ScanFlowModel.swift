import UIKit

// Explicit, testable state machine for the scan flow.
//
// WHY THIS EXISTS
// Today the "entry → scanning → reviewing" phase is not stored anywhere — it's
// an emergent cross-product of `localStage`, `session.showScanFound`, and
// `capturedImage != nil` scattered across ScanFlowCoordinator's @State. That
// makes the transitions impossible to unit-test (they live inside a SwiftUI
// View, wrapped in timers/animations/UIKit) and easy to break.
//
// This type names the phase and the transitions as plain data + methods, with
// NO SwiftUI, NO timers, NO UIKit — so they can be exercised directly in tests.
//
// ADOPTION STATUS (read before refactoring)
// ScanFlowCoordinator currently calls these methods ALONGSIDE its existing
// @State mutations, at the exact transition points — the model shadows the
// View's state rather than driving it yet. The characterization tests pin the
// semantics below to today's behavior, so the upcoming refactor can consolidate
// the View onto this model and rely on a red test to catch any drift.
//
// Each method mirrors a specific ScanFlowCoordinator function — see the //  ← notes.
// The small asymmetries between cancel()/reset()/scanFailed() are REAL and
// intentional here: they characterize what the code does today, not what it
// "should" do. Do not "clean them up" without a corresponding test change.
@MainActor
@Observable
final class ScanFlowModel {

    enum Phase: Equatable {
        case entry      // idle: menu/camera chrome, no scan in flight
        case scanning   // photo committed, FrijAPI.scan in flight
        case reviewing  // scan returned, found panel up over the photo
    }

    private(set) var phase: Phase = .entry
    /// Whether the phase currently intends to have a captured photo backing the
    /// flow. Set by the transitions below. This is NOT the same as
    /// `capturedImage != nil`: it flips false at scan-fail/cancel/reset while
    /// `capturedImage` lingers a beat longer so the photo can fade out.
    private(set) var hasCapture: Bool = false
    /// The captured fridge photo backing the flow, or nil. Owned here now (it
    /// used to be a loose @State on the View). The View still picks the exact
    /// moment to set/clear it — at scan-fail/cancel/reset the bitmap is cleared a
    /// beat AFTER `hasCapture` goes false so it can fade out — so this stays a
    /// settable property (like `lastError`), not folded into the transitions.
    var capturedImage: UIImage?
    /// The scan items surfaced to the user — high-confidence only, so what the
    /// review sheet shows equals what got merged into the pantry. Mirrors
    /// `session.scanDetectedItems`. The View filters to high-confidence before
    /// both merging AND display; that filtering is not this model's job.
    private(set) var detected: [DetectedItem] = []
    /// User-facing scan error, or nil. Mirrors the View's `scanError`.
    var lastError: String?

    // MARK: Transitions

    /// Capture committed, scan kicked off.
    /// ← ScanFlowCoordinator.handleCameraCapture (the +1.7s commit block) and
    ///   handleImage (the Photos path). Leaves `detected`/`lastError` untouched;
    ///   the View clears the error at menu-open / photo-load, before this fires.
    func beginScan() {
        phase = .scanning
        hasCapture = true
    }

    /// Scan succeeded — hand off to review with the photo still behind the panel.
    /// ← ScanFlowCoordinator.runScan success branch.
    /// `hasCapture` deliberately STAYS true so the photo never flickers off
    /// between scan-complete and panel-appear.
    func scanSucceeded(_ items: [DetectedItem]) {
        detected = items
        phase = .reviewing
    }

    /// Scan failed — back to entry, drop the photo, surface the error.
    /// ← ScanFlowCoordinator.runScan catch branch.
    /// NOTE: `detected` is intentionally NOT cleared here — the catch block
    /// leaves `session.scanDetectedItems` as-is. Characterized as-is.
    func scanFailed(_ message: String) {
        phase = .entry
        hasCapture = false
        lastError = message
    }

    /// User cancelled the in-flight scan.
    /// ← ScanFlowCoordinator.cancelScan. Clears `detected` (mirrors
    /// `session.scanDetectedItems = []`) but leaves `lastError` untouched
    /// (cancelScan doesn't clear the error).
    func cancel() {
        phase = .entry
        hasCapture = false
        detected = []
    }

    /// Return to the entry screen (e.g. the overview sheet was dismissed).
    /// ← ScanFlowCoordinator.resetToEntry. Drops the photo but — matching today's
    /// behavior — leaves `detected` and `lastError` untouched.
    func reset() {
        phase = .entry
        hasCapture = false
    }
}
