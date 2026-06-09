import SwiftUI

struct StreakCelebrationView: View {
    @State private var cardScale: CGFloat = 0.72
    @State private var cardOpacity: Double = 0
    @State private var flameScale: CGFloat = 0.35
    @State private var scrimOpacity: Double = 0

    private let coordinator = CelebrationCoordinator.shared
    private let cooking = CookingStore.shared

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .opacity(scrimOpacity)

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 6) {
                    Text("Let's go!")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.28, green: 0.12, blue: 0.02))
                    Text("You're on fire today 🔥")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.55, green: 0.28, blue: 0.05))
                }
                .padding(.top, 32)

                // Flame + streak number
                ZStack(alignment: .bottom) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 112))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.88, blue: 0.0), .orange],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: .orange.opacity(0.35), radius: 24, y: 12)
                        .scaleEffect(flameScale)

                    Text("\(coordinator.streak)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.22, green: 0.08, blue: 0.01))
                        .offset(y: 10)
                }
                .frame(height: 145)

                // Subtitle
                VStack(spacing: 3) {
                    Text(coordinator.streak > 1 ? "\(coordinator.streak) meals cooked in a row" : "First meal — keep it going!")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.orange)
                    Text(coordinator.streak > 1 ? "You're on a roll 🎉" : "One down, many to go.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.22, blue: 0.04))
                }
                .multilineTextAlignment(.center)

                // Week strip
                weekStrip
                    .padding(.horizontal, 8)

                // CTA button
                Button(action: handleDismiss) {
                    HStack(spacing: 10) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Keep it up!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Spacer()
                        Text("You're doing amazing")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .opacity(0.65)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        Color.white.opacity(0.82),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.97, blue: 0.85),
                        Color(red: 1.0, green: 0.87, blue: 0.50),
                    ],
                    startPoint: .top, endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 32, style: .continuous)
            )
            .padding(.horizontal, 28)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) { scrimOpacity = 1 }
            withAnimation(.spring(response: 0.46, dampingFraction: 0.60)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.50).delay(0.08)) {
                flameScale = 1.0
            }
        }
    }

    // MARK: Week strip

    private var weekStrip: some View {
        HStack(spacing: 5) {
            ForEach(currentWeekDays(), id: \.self) { date in
                let cooked = cooking.hasCooked(on: date)
                VStack(spacing: 5) {
                    Text(weekdayLabel(date))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.45, green: 0.25, blue: 0.05).opacity(0.7))

                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(cooked ? Color.orange : Color.black.opacity(0.08))
                            .frame(width: 38, height: 38)
                        if cooked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func handleDismiss() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            cardScale = 0.86
            cardOpacity = 0
            scrimOpacity = 0
        }
        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            coordinator.dismiss()
        }
    }

    private func currentWeekDays() -> [Date] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        guard let sunday = cal.date(byAdding: .day, value: -(weekday - 1), to: today) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: sunday) }
    }

    private func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        f.locale = Locale(identifier: "en_US_POSIX")
        return String(f.string(from: date).prefix(2))
    }
}
