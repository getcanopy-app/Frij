import SwiftUI

/// Enter a creator's referral code for bonus free meals. Validates against the
/// backend (/api/redeem), grants the bonus once per install, and — because the
/// redemption is logged server-side against this device — lets a later
/// subscription be attributed to the creator for their payout.
struct CreatorCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var usage = UsageStore.shared

    @State private var code = ""
    @State private var state: RedeemPhase = .idle
    @FocusState private var focused: Bool

    private enum RedeemPhase: Equatable {
        case idle, loading, success(Int), invalid, error
    }

    var body: some View {
        VStack(spacing: FridjSpacing.md) {
            Capsule().fill(Color.fridjText.opacity(0.15))
                .frame(width: 38, height: 5).padding(.top, 8)

            Image(systemName: "gift.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.fridjOrange)
                .padding(.top, 4)

            Text("Have a creator code?")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)
            Text("Enter it for bonus free meals on us.")
                .font(FridjFont.size(14))
                .foregroundColor(.fridjText.opacity(0.55))
                .multilineTextAlignment(.center)

            if case let .success(meals) = state {
                Label("\(meals) bonus meals added!", systemImage: "checkmark.circle.fill")
                    .font(FridjFont.size(16, weight: .bold))
                    .foregroundColor(.fridjGreen)
                    .padding(.vertical, 10)
            } else {
                TextField("CODE", text: $code)
                    .focused($focused)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(FridjFont.size(20, weight: .bold))
                    .foregroundColor(.fridjText)
                    .padding(.vertical, 14)
                    .background(Color(white: 1), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(borderColor, lineWidth: 1.5))
                    .padding(.horizontal, 4)
                    .onChange(of: code) { if state == .invalid || state == .error { state = .idle } }

                if state == .invalid {
                    Text("That code isn't valid. Double-check it?")
                        .font(FridjFont.size(13, weight: .medium)).foregroundColor(.fridjCoral)
                } else if state == .error {
                    Text("Couldn't reach Frij. Try again in a sec.")
                        .font(FridjFont.size(13, weight: .medium)).foregroundColor(.fridjCoral)
                }

                Button(action: redeem) {
                    Group {
                        if state == .loading { ProgressView().tint(.white) }
                        else { Text("Apply code") }
                    }
                    .font(FridjFont.size(16, weight: .bold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(canSubmit ? Color.fridjOrange : Color.fridjOrange.opacity(0.4),
                                in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FridjSpacing.lg)
        .background(Color.fridjBg)
        .onAppear { focused = true }
    }

    private var canSubmit: Bool {
        state != .loading && code.trimmingCharacters(in: .whitespaces).count >= 2
    }
    private var borderColor: Color {
        (state == .invalid || state == .error) ? .fridjCoral.opacity(0.7) : .fridjText.opacity(0.15)
    }

    private func redeem() {
        let entered = code.trimmingCharacters(in: .whitespaces).uppercased()
        guard entered.count >= 2 else { return }
        focused = false
        state = .loading
        Task {
            do {
                if let meals = try await FrijAPI.redeemCreatorCode(entered), meals > 0 {
                    usage.applyCreatorBonus(meals, code: entered)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        state = .success(meals)
                    }
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    dismiss()
                } else {
                    withAnimation { state = .invalid }
                }
            } catch {
                withAnimation { state = .error }
            }
        }
    }
}

#Preview {
    Color.fridjBg.sheet(isPresented: .constant(true)) {
        CreatorCodeSheet().presentationDetents([.height(340)])
    }
}
