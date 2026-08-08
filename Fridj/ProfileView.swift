import SwiftUI

struct ProfileView: View {
    @State private var store = ProfileStore.shared
    @State private var sub = SubscriptionManager.shared
    @State private var usage = UsageStore.shared
    @Environment(\.dismiss) private var dismiss
    // Hidden admin toggle — 7 taps on "About you" flips isAdmin.
    @State private var adminTapCount = 0
    @State private var adminTapResetTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fridjBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FridjSpacing.xl) {
                        subscriptionCard

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("About you")
                                    .font(FridjFont.style(.title, weight: .bold))
                                    .foregroundColor(.fridjText)
                                    .contentShape(Rectangle())
                                    .onTapGesture { handleAdminTap() }
                                if usage.isAdmin {
                                    Text("ADMIN")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.fridjOrange, in: Capsule())
                                }
                            }
                            Text("Frij uses this to make recipes that actually fit you.")
                                .font(FridjFont.size(14))
                                .foregroundColor(.fridjText.opacity(0.5))
                        }

                        // Diet
                        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                            Text("Dietary preferences")
                                .font(FridjFont.size(15, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Free text. \"High protein, no pork.\" \"Pescatarian.\" Whatever fits.")
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjText.opacity(0.5))
                            TextField("e.g. high protein, no pork", text: $store.profile.diet, axis: .vertical)
                                .lineLimit(2...4)
                                .font(FridjFont.size(15))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                        }

                        // Cuisine
                        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                            Text("Cuisines you love")
                                .font(FridjFont.size(15, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Frij leans this way when your ingredients fit. Skip it and dinners are still great.")
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjText.opacity(0.5))
                            TextField("e.g. Persian, Italian, Thai", text: $store.profile.cuisine, axis: .vertical)
                                .lineLimit(2...4)
                                .font(FridjFont.size(15))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                        }

                        // Household
                        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                            Text("Cooking for")
                                .font(FridjFont.size(15, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Frij will scale recipe portions to match.")
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjText.opacity(0.5))
                            HStack(spacing: FridjSpacing.sm) {
                                ForEach(HouseholdSize.allCases) { size in
                                    Button {
                                        if store.profile.household == size {
                                            store.profile.household = nil  // tap again to deselect
                                        } else {
                                            store.profile.household = size
                                        }
                                    } label: {
                                        Text(size.label)
                                            .font(FridjFont.size(14, weight: .bold))
                                            .foregroundColor(store.profile.household == size ? .white : .fridjText.opacity(0.7))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                store.profile.household == size ? Color.fridjGreen : .white,
                                                in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous)
                                                    .stroke(Color.fridjText.opacity(store.profile.household == size ? 0 : 0.12), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }

                        // Dislikes
                        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                            Text("Things to avoid")
                                .font(FridjFont.size(15, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Foods you hate, allergies, picky kid stuff — anything Frij should steer clear of.")
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjText.opacity(0.5))
                            TextField("e.g. no cilantro, no mushrooms", text: $store.profile.dislikes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(FridjFont.size(15))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                        }

                        // Legal
                        HStack(spacing: 18) {
                            Link("Terms of Use", destination: FrijLinks.terms)
                            Link("Privacy Policy", destination: FrijLinks.privacy)
                            Spacer()
                        }
                        .font(FridjFont.size(13, weight: .medium))
                        .foregroundColor(.fridjText.opacity(0.5))
                    }
                    .padding(.horizontal, FridjSpacing.lg)
                    .padding(.top, FridjSpacing.sm)
                    .padding(.bottom, FridjSpacing.xl)
                }
                // Kill the iOS 26 scroll-edge "pocket" — the soft dimmed band
                // the scroll view paints under the top bar. That was the
                // full-width line hovering above the card, not a border on the
                // card itself.
                .scrollEdgeEffectHidden(true, for: .top)
            }
            // Hide the nav bar's material + hairline so the cream background
            // flows straight into the card — the "Done" button stays, but the
            // separator shadow that cut across the top is gone.
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(FridjFont.size(16, weight: .bold))
                        .foregroundColor(.fridjOrange)
                }
            }
        }
    }

    // MARK: Subscription card

    @ViewBuilder
    private var subscriptionCard: some View {
        if sub.isSubscribed {
            // Active subscriber — show status
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.fridjGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text("F+")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.fridjGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Frij+")
                            .font(FridjFont.size(16, weight: .bold))
                            .foregroundColor(.fridjText)
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.fridjGreen, in: Capsule())
                    }
                    Text("Unlimited recipes · all features unlocked")
                        .font(FridjFont.size(12))
                        .foregroundColor(.fridjText.opacity(0.5))
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.fridjGreen)
            }
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous)
                    .stroke(Color.fridjGreen.opacity(0.25), lineWidth: 1)
            )
        } else {
            // Free tier — show upgrade card. Profile is a sheet, and iOS can't
            // present a sheet ON TOP of another sheet. So we dismiss Profile
            // first, then trigger the paywall after the dismiss animation
            // completes (~0.35s system default).
            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    sub.showPaywall = true
                }
            } label: {
                HStack(spacing: 16) {
                    // The Frij logo in a rounded tile — a white edge lifts the
                    // fridge off the orange fill so it reads as a premium badge.
                    Image("FridjLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(.white.opacity(0.85), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Upgrade to Frij+")
                            .font(FridjFont.size(21, weight: .bold))
                            .foregroundColor(.white)
                        Text(usage.remaining > 0
                             ? "\(usage.remaining) free idea\(usage.remaining == 1 ? "" : "s") left · $2.99/mo"
                             : "Free ideas used up · unlock unlimited")
                            .font(FridjFont.size(13))
                            .foregroundColor(.white.opacity(0.9))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 22)
                .background(
                    LinearGradient(
                        colors: [Color.fridjOrange, Color.fridjCoral],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous)
                )
                .shadow(color: Color.fridjOrange.opacity(0.38), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(.plain)
        }
    }

    // 7 taps on the "About you" title within 3 seconds toggles admin mode.
    private func handleAdminTap() {
        adminTapCount += 1
        adminTapResetTask?.cancel()
        if adminTapCount >= 7 {
            usage.toggleAdmin()
            adminTapCount = 0
            // Haptic feedback would go here if we had a helper — for now the
            // ADMIN badge appearing/disappearing is the confirmation.
            return
        }
        // Reset the counter if the user pauses for more than 3s.
        adminTapResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            adminTapCount = 0
        }
    }
}

#Preview {
    ProfileView()
}
