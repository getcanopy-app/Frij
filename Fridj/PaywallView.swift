import SwiftUI
import StoreKit

// Update these two URLs before App Store submission.
private enum FrijLinks {
    static let terms   = URL(string: "https://frij.app/terms")!
    static let privacy = URL(string: "https://frij.app/privacy")!
}

struct PaywallView: View {
    @State private var sub = SubscriptionManager.shared
    @State private var usage = UsageStore.shared
    @State private var selectedPlan: Plan = .annual
    @Environment(\.dismiss) private var dismiss

    // Animation state
    @State private var badgeScale: CGFloat = 0.4
    @State private var badgeRotation: Double = -8
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16
    @State private var featuresVisible: [Bool] = Array(repeating: false, count: 5)
    @State private var plansOffset: CGFloat = 40
    @State private var plansOpacity: Double = 0
    @State private var ctaOffset: CGFloat = 40
    @State private var ctaOpacity: Double = 0

    // Error toast — swipe-to-dismiss offset + auto-fade timer.
    @State private var toastDragOffset: CGFloat = 0
    @State private var toastDismissTask: Task<Void, Never>? = nil

    enum Plan { case monthly, annual }

    private let features: [(icon: String, color: Color, title: String, detail: String)] = [
        ("infinity",        .fridjOrange, "Unlimited recipe ideas",    "New dinners every time you ask"),
        ("camera.fill",     .fridjGreen,  "Unlimited kitchen scans",   "Scan as much as you want"),
        ("heart.fill",      .pink,        "Save your favorites",       "Build your personal recipe book"),
        ("cart.fill",       .blue,        "Smart grocery lists",       "Auto-add what you're missing"),
        ("flame.fill",      .orange,      "Streak & progress",         "Stay on your cooking game"),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            Color.fridjBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 72)

                    featuresSection
                        .padding(.top, 32)
                        .padding(.horizontal, 20)

                    plansSection
                        .padding(.top, 28)
                        .padding(.horizontal, 20)
                        .opacity(plansOpacity)
                        .offset(y: plansOffset)

                    ctaSection
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        .opacity(ctaOpacity)
                        .offset(y: ctaOffset)

                    legalSection
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 48)
                        .opacity(ctaOpacity)
                }
            }

            // Close button
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.trailing, 20)
                .padding(.top, 16)
            }

            // Error toast — auto-dismisses after 3s, or user can swipe down.
            // Transition MUST be on the outermost view that's conditionally
            // present (the VStack), otherwise SwiftUI removes the parent
            // before the child's transition can fire — that's why the old
            // version snapped out instead of fading.
            if let err = sub.purchaseError {
                VStack {
                    Spacer()
                    Text(err)
                        .font(FridjFont.size(14, weight: .medium))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20).padding(.vertical, 14)
                        .background(Color.fridjText,
                                    in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .offset(y: max(0, toastDragOffset))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    toastDragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    if value.translation.height > 40 || value.predictedEndTranslation.height > 100 {
                                        toastDismissTask?.cancel()
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            sub.purchaseError = nil
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            toastDragOffset = 0
                                        }
                                    }
                                }
                        )
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: sub.purchaseError)
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .onAppear { animateIn() }
        // Auto-fade the error toast after 3 seconds. Reset the drag offset
        // whenever a new error appears so a swipe-dismissed toast doesn't
        // reappear off-screen the next time.
        .onChange(of: sub.purchaseError) { _, newValue in
            toastDismissTask?.cancel()
            toastDragOffset = 0
            guard newValue != nil else { return }
            toastDismissTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    sub.purchaseError = nil
                }
            }
        }
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Animated badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.fridjOrange, Color(red: 1, green: 0.55, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.fridjOrange.opacity(0.45), radius: 24, x: 0, y: 10)

                VStack(spacing: -4) {
                    Text("F+")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(badgeScale)
            .rotationEffect(.degrees(badgeRotation))

            VStack(spacing: 10) {
                Text("Unlock Frij+")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Cook smarter every night.\nWaste nothing.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .opacity(titleOpacity)
            .offset(y: titleOffset)
        }
    }

    // MARK: Features

    private var featuresSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { idx, f in
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(f.color.opacity(0.12))
                            .frame(width: 46, height: 46)
                        Image(systemName: f.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(f.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(f.detail)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.fridjGreen)
                }
                .padding(.vertical, 13)
                .opacity(featuresVisible[idx] ? 1 : 0)
                .offset(x: featuresVisible[idx] ? 0 : 28)

                if idx < features.count - 1 {
                    Divider().padding(.leading, 62)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
    }

    // MARK: Plans

    private var plansSection: some View {
        VStack(spacing: 14) {
            Text("Choose your plan")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                planCard(
                    plan: .monthly,
                    title: "Monthly",
                    priceDisplay: sub.products.first(where: { $0.id == SubscriptionManager.monthlyID })?.displayPrice ?? "$2.99",
                    sub: "per month",
                    badge: nil
                )

                planCard(
                    plan: .annual,
                    title: "Annual",
                    priceDisplay: sub.products.first(where: { $0.id == SubscriptionManager.annualID })?.displayPrice ?? "$19.99",
                    sub: "per year · save 44%",
                    badge: "Best Value"
                )
            }
        }
    }

    private func planCard(plan: Plan, title: String, priceDisplay: String, sub subText: String, badge: String?) -> some View {
        let selected = selectedPlan == plan
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPlan = plan } } label: {
            VStack(spacing: 6) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Color.fridjOrange, in: Capsule())
                } else {
                    Color.clear.frame(height: 20)
                }

                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(selected ? Color.fridjOrange : .primary)

                Text(priceDisplay)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(selected ? Color.fridjOrange : .primary)

                Text(subText)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Color.fridjOrange.opacity(0.07) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(selected ? Color.fridjOrange : Color.black.opacity(0.1),
                                    lineWidth: selected ? 2 : 1)
                    )
                    .shadow(color: selected ? Color.fridjOrange.opacity(0.15) : .clear,
                            radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: CTA

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let id = selectedPlan == .monthly ? SubscriptionManager.monthlyID : SubscriptionManager.annualID
                    guard let product = sub.products.first(where: { $0.id == id }) else { return }
                    await sub.purchase(product)
                }
            } label: {
                HStack(spacing: 10) {
                    if sub.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Continue with Frij+")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .black))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Color.fridjOrange,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .shadow(color: Color.fridjOrange.opacity(0.4), radius: 14, x: 0, y: 6)
            }
            .disabled(sub.isPurchasing)
            .scaleEffect(sub.isPurchasing ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: sub.isPurchasing)

            if !sub.isSubscribed && usage.remaining > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.fridjOrange)
                    Text("\(usage.remaining) free recipe idea\(usage.remaining == 1 ? "" : "s") remaining")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Legal

    private var legalSection: some View {
        VStack(spacing: 10) {
            Button("Restore Purchases") {
                Task { await sub.restore() }
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Link("Terms of Use", destination: FrijLinks.terms)
                Link("Privacy Policy", destination: FrijLinks.privacy)
            }
            .font(.system(size: 12, design: .rounded))
            .foregroundStyle(.secondary.opacity(0.7))

            Text("Subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Cancel anytime in your iPhone Settings.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Entrance animation

    private func animateIn() {
        // Badge bounces in
        withAnimation(.spring(response: 0.65, dampingFraction: 0.5)) {
            badgeScale = 1
            badgeRotation = 0
        }
        // Title fades up
        withAnimation(.easeOut(duration: 0.45).delay(0.18)) {
            titleOpacity = 1
            titleOffset = 0
        }
        // Features stagger in from right
        for i in features.indices {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.3 + Double(i) * 0.07)) {
                featuresVisible[i] = true
            }
        }
        // Plans slide up
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.72)) {
            plansOffset = 0
            plansOpacity = 1
        }
        // CTA slides up last
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.86)) {
            ctaOffset = 0
            ctaOpacity = 1
        }
    }
}

#Preview {
    PaywallView()
}
