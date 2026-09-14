import Foundation
import UIKit

/// Invite state: this device's code, how many friends have joined, and the
/// meals/Frij+ that earned.
///
/// The server owns the ledger. This never decides how many meals to grant —
/// it asks, and applies whatever comes back. That's deliberate: if the app
/// tracked what it had claimed, a reinstall would reset that to zero and
/// re-grant every meal ever earned.
///
/// Every call is best-effort. Invites are a growth feature and must never be
/// able to break cooking, so failures are swallowed into state rather than
/// thrown at the UI.
@MainActor @Observable
final class InviteStore {
    static let shared = InviteStore()

    private(set) var summary: InviteSummary?
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Set when a friend's code was found on the clipboard and not yet acted
    /// on. Drives the "Got a code from a friend?" prompt.
    var pendingClipboardCode: String?

    /// Meals just granted, for the celebratory moment. Cleared once shown.
    var justGranted: Int?

    private let redeemedKey = "frij.invite.redeemedCode"
    private let promptedKey = "frij.invite.clipboardPrompted"

    /// A device may accept exactly one invite, ever. Mirrored server-side by
    /// the invite_redemptions primary key; kept here too so the UI can stop
    /// offering something that will be refused.
    private(set) var redeemedCode: String? {
        didSet { UserDefaults.standard.set(redeemedCode, forKey: redeemedKey) }
    }
    var hasRedeemed: Bool { redeemedCode != nil }

    private init() {
        redeemedCode = UserDefaults.standard.string(forKey: redeemedKey)
    }

    var code: String? { summary?.code }
    var shareLink: String { summary.map(\.link) ?? "https://hellofrij.com" }
    var successfulInvites: Int { summary?.successfulInvites ?? 0 }

    var shareMessage: String {
        "I use Frij to figure out dinner from what's in my fridge — "
        + "here's 5 free meals: \(shareLink)"
    }

    // MARK: Loading

    /// Fetches (creating on first run) this device's code and totals, then
    /// claims anything owed. Safe to call often; it no-ops while in flight.
    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // The backend is serverless, so the first request after a deploy can
        // cold-start and fail. That would show "couldn't load your code" to
        // whoever opens this first, for no real reason — so retry once.
        for attempt in 0..<2 {
            do {
                let s = summary == nil ? try await FrijAPI.inviteCreate()
                                       : try await FrijAPI.inviteStatus()
                summary = s
                lastError = nil
                SubscriptionManager.shared.applyPlusGrant(until: s.plusUntil)
                if s.unclaimedMeals > 0 { await claim() }
                return
            } catch {
                // Keep whatever we last knew — a dropped connection shouldn't
                // blank out someone's invite count.
                lastError = error.localizedDescription
                if attempt == 0 { try? await Task.sleep(nanoseconds: 1_200_000_000) }
            }
        }
    }

    /// Asks the server for any meals owed and credits them locally. The server
    /// decides the amount and marks it claimed in the same operation, so this
    /// can't double-grant even if called twice.
    func claim() async {
        do {
            let granted = try await FrijAPI.inviteClaim()
            guard granted > 0 else { return }
            UsageStore.shared.applyInviteMeals(granted)
            justGranted = granted
            summary = try? await FrijAPI.inviteStatus()
            if let until = summary?.plusUntil {
                SubscriptionManager.shared.applyPlusGrant(until: until)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: Redeeming a friend's code

    enum RedeemOutcome: Equatable {
        case granted(Int)
        case alreadyRedeemed
        case ownCode
        case invalid
        case unavailable
    }

    @discardableResult
    func redeem(_ raw: String) async -> RedeemOutcome {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return .invalid }
        guard !hasRedeemed else { return .alreadyRedeemed }

        do {
            let (meals, error) = try await FrijAPI.inviteRedeem(code)
            if let meals {
                redeemedCode = code
                pendingClipboardCode = nil
                UsageStore.shared.applyInviteMeals(meals)
                justGranted = meals
                return .granted(meals)
            }
            switch error {
            case "already_redeemed":
                redeemedCode = code          // the server knows; stop asking
                pendingClipboardCode = nil
                return .alreadyRedeemed
            case "own_code":     return .ownCode
            case "invalid_code": return .invalid
            default:             return .unavailable
            }
        } catch {
            return .unavailable
        }
    }

    // MARK: Clipboard hand-off

    /// Looks for a friend's code on the clipboard.
    ///
    /// IMPORTANT: only call this from an explicit user tap. iOS shows a system
    /// "Allow Paste?" alert whenever an app reads the pasteboard, and firing
    /// that unprompted on first launch is alarming — the user hasn't even seen
    /// the app yet. Behind a tap, the prompt has obvious context.
    ///
    /// `hasCandidateCode` below is the safe part: it can be called freely
    /// because pattern detection does NOT read the contents or prompt.
    func readClipboardCode() -> String? {
        guard !hasRedeemed else { return nil }
        guard let raw = UIPasteboard.general.string else { return nil }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        // A bare code, or the tail of a hellofrij.com/i/CODE link.
        let candidate = cleaned.contains("/I/")
            ? String(cleaned.split(separator: "/").last ?? "")
            : cleaned
        let valid = candidate.count >= 4 && candidate.count <= 12
            && candidate.allSatisfy { $0.isLetter || $0.isNumber }
        return valid ? candidate : nil
    }

    /// Whether to offer the "Got a code from a friend?" prompt at all. Uses
    /// `detectPatterns`, which tells us a URL is present WITHOUT reading it and
    /// without prompting — so the offer only appears when it plausibly applies.
    func hasCandidateCode() async -> Bool {
        guard !hasRedeemed else { return false }
        guard !UserDefaults.standard.bool(forKey: promptedKey) else { return false }
        // Completion-handler form: this SDK has no async overload.
        let patterns: Set<UIPasteboard.DetectionPattern> = await withCheckedContinuation { cont in
            UIPasteboard.general.detectPatterns(for: [.probableWebURL, .number]) { result in
                cont.resume(returning: (try? result.get()) ?? [])
            }
        }
        return !patterns.isEmpty
    }

    func markClipboardPrompted() {
        UserDefaults.standard.set(true, forKey: promptedKey)
    }
}

/// Decides WHEN to nudge someone to invite a friend.
///
/// The rule is deliberately conservative: the second time you cook, then every
/// fifth. Asking after every cook is nagging, and asking after the first one
/// lands before Frij has earned anything. Peak satisfaction — you just made
/// dinner — is the moment worth using, but only occasionally.
@MainActor @Observable
final class InviteNudge {
    static let shared = InviteNudge()

    private let cookCountKey = "frij.invite.cooksSinceNudge.total"
    private let dismissedKey = "frij.invite.nudgeDismissedForever"

    /// Set when it's time to offer; ContentView presents on this.
    var isShowing = false

    private var totalCooks: Int {
        get { UserDefaults.standard.integer(forKey: cookCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: cookCountKey) }
    }
    private var dismissedForever: Bool {
        get { UserDefaults.standard.bool(forKey: dismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: dismissedKey) }
    }

    /// Called from CookLog so it fires wherever the user cooked from.
    func recordCook() {
        guard !dismissedForever else { return }
        totalCooks += 1
        let n = totalCooks
        guard n == 2 || (n > 2 && n % 5 == 0) else { return }
        // Let the cooking celebration land first — this is a second beat, not
        // a competing one.
        Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            isShowing = true
        }
    }

    /// "Don't show this again" — respected permanently.
    func stopAsking() {
        dismissedForever = true
        isShowing = false
    }
}
