import SwiftUI

/// "Invite friends" — the canonical invite screen.
///
/// Framed as generosity, not a chore: the headline is what the FRIEND gets,
/// and what the user earns is the quieter second beat. A referral screen that
/// leads with "earn rewards" reads as work.
struct InviteView: View {
    @State private var store = InviteStore.shared
    @State private var showShare = false
    @State private var copied = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: FridjSpacing.lg) {
                header
                codeCard
                shareButton
                if store.successfulInvites > 0 || store.summary?.nextMilestone != nil {
                    progressCard
                }
                howItWorks
            }
            .padding(.horizontal, FridjSpacing.md)
            .padding(.bottom, FridjSpacing.xl)
        }
        .background(Color.fridjBg.ignoresSafeArea())
        .navigationTitle("Invite friends")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refresh() }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [store.shareMessage])
        }
    }

    private var header: some View {
        VStack(spacing: FridjSpacing.sm) {
            ChefLoaderView(size: 104)
                .accessibilityHidden(true)
            Text("Give a friend 5 free meals")
                .font(FridjFont.size(26, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.fridjText)
            Text("They get 5 meals when they join. You get 5 when they cook their first one.")
                .font(FridjFont.size(15, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.fridjText.opacity(0.6))
                .padding(.horizontal, FridjSpacing.sm)
        }
        .padding(.top, FridjSpacing.md)
    }

    private var codeCard: some View {
        VStack(spacing: FridjSpacing.sm) {
            Text("YOUR CODE")
                .font(FridjFont.size(11, weight: .bold))
                .tracking(1.4)
                .foregroundColor(.fridjText.opacity(0.4))

            if let code = store.code {
                Text(code)
                    .font(FridjFont.size(34, weight: .bold))
                    .tracking(6)
                    .foregroundColor(.fridjText)
                Button {
                    UIPasteboard.general.string = store.shareLink
                    withAnimation(.spring(response: 0.3)) { copied = true }
                    Task {
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        withAnimation { copied = false }
                    }
                } label: {
                    Label(copied ? "Link copied" : "Copy link",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(FridjFont.size(14, weight: .bold))
                        .foregroundColor(.fridjOrange)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            } else if store.isLoading {
                ProgressView().frame(height: 58)
            } else {
                // Never a dead end: the screen still explains itself offline.
                Text("Couldn't load your code")
                    .font(FridjFont.size(15, weight: .semibold))
                    .foregroundColor(.fridjText.opacity(0.5))
                Button("Try again") { Task { await store.refresh() } }
                    .font(FridjFont.size(14, weight: .bold))
                    .foregroundColor(.fridjOrange)
                    .frame(minHeight: 44)
                #if DEBUG
                // Debug builds show why, so a failure here is diagnosable
                // without attaching a debugger. Never shown in Release.
                if let err = store.lastError {
                    Text(err)
                        .font(FridjFont.size(10))
                        .foregroundColor(.fridjCoral)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                #endif
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FridjSpacing.lg)
        .background(Color.white, in: RoundedRectangle(cornerRadius: FridjRadius.recipeCard,
                                                     style: .continuous))
        .shadow(color: .black.opacity(0.07), radius: 14, y: 6)
    }

    private var shareButton: some View {
        Button {
            showShare = true
        } label: {
            Label("Share with a friend", systemImage: "square.and.arrow.up")
                .font(FridjFont.size(17, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.fridjOrange, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.code == nil)
        .opacity(store.code == nil ? 0.5 : 1)
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            HStack {
                Text("\(store.successfulInvites) friend\(store.successfulInvites == 1 ? "" : "s") joined")
                    .font(FridjFont.size(17, weight: .bold))
                    .foregroundColor(.fridjText)
                Spacer()
                if let earned = store.summary?.mealsEarned, earned > 0 {
                    Text("+\(earned) meals")
                        .font(FridjFont.size(14, weight: .bold))
                        .foregroundColor(.fridjGreen)
                }
            }

            if let next = store.summary?.nextMilestone {
                ProgressView(value: min(1, store.summary?.milestoneProgress ?? 0))
                    .tint(.fridjOrange)
                Text("\(next.remaining) more for \(next.label)")
                    .font(FridjFont.size(13, weight: .semibold))
                    .foregroundColor(.fridjText.opacity(0.55))
            } else if let until = store.summary?.plusUntil {
                Label("Frij+ until \(until.formatted(date: .abbreviated, time: .omitted))",
                      systemImage: "sparkles")
                    .font(FridjFont.size(13, weight: .bold))
                    .foregroundColor(.fridjOrange)
            }
        }
        .padding(FridjSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: FridjRadius.md,
                                                     style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
            step("1", "Send your link", "They get 5 free meals when they join.")
            step("2", "They cook something", "Your 5 meals land once they've made their first dish.")
            step("3", "Keep going", "3 friends earns a week of Frij+. 10 earns a month.")
        }
        .padding(.top, FridjSpacing.sm)
    }

    private func step(_ n: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: FridjSpacing.sm) {
            Text(n)
                .font(FridjFont.size(13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.fridjOrange, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FridjFont.size(15, weight: .bold))
                    .foregroundColor(.fridjText)
                Text(body)
                    .font(FridjFont.size(13, weight: .medium))
                    .foregroundColor(.fridjText.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// The system share sheet comes from FridgeRoast.swift's ShareSheet — one
// bridge for the whole app rather than a second identical one here.

/// The "a friend sent you a code" prompt. Shown only after an explicit tap,
/// because reading the clipboard triggers an iOS permission alert.
struct RedeemInvitePrompt: View {
    @State private var store = InviteStore.shared
    @State private var working = false
    @State private var message: String?
    var onDone: () -> Void

    var body: some View {
        VStack(spacing: FridjSpacing.md) {
            Text("🎁").font(.system(size: 44))
            Text("Got a code from a friend?")
                .font(FridjFont.size(21, weight: .bold))
                .foregroundColor(.fridjText)
            Text("We'll check your clipboard for their code and add 5 meals.")
                .font(FridjFont.size(14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.fridjText.opacity(0.6))

            if let message {
                Text(message)
                    .font(FridjFont.size(14, weight: .bold))
                    .foregroundColor(.fridjOrange)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await check() }
            } label: {
                Text(working ? "Checking…" : "Check for my code")
                    .font(FridjFont.size(16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.fridjOrange, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(working)

            Button("Not now") {
                store.markClipboardPrompted()
                onDone()
            }
            .font(FridjFont.size(14, weight: .semibold))
            .foregroundColor(.fridjText.opacity(0.5))
            .frame(minHeight: 44)
        }
        .padding(FridjSpacing.lg)
    }

    private func check() async {
        working = true
        defer { working = false }
        store.markClipboardPrompted()

        // This is the line that triggers iOS's paste alert — deliberately
        // behind the button so the user just asked for it.
        guard let code = store.readClipboardCode() else {
            message = "No code found. Ask your friend to send their link again."
            return
        }
        switch await store.redeem(code) {
        case .granted(let meals):
            message = "🎉 \(meals) meals added!"
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            onDone()
        case .ownCode:         message = "That's your own code."
        case .alreadyRedeemed: message = "You've already used an invite code."
        case .invalid:         message = "That code isn't valid."
        case .unavailable:     message = "Couldn't reach Frij. Try again in a moment."
        }
    }
}
