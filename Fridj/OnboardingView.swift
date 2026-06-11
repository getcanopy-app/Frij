import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "camera.viewfinder",
            iconColor: Color(red: 0.25, green: 0.55, blue: 0.95),
            title: "Point.\nScan. Done.",
            subtitle: "Photograph your fridge or counter and Frij identifies everything in your kitchen — no typing needed."
        ),
        OnboardingPage(
            icon: "fork.knife",
            iconColor: Color(red: 0.98, green: 0.55, blue: 0.25),
            title: "Tonight's dinner,\nsorted.",
            subtitle: "Get 3 personalized recipes based on exactly what you have. No guessing, no googling, no wasted food."
        ),
        OnboardingPage(
            icon: "flame.fill",
            iconColor: Color(red: 0.98, green: 0.75, blue: 0.15),
            title: "Build your\ncooking streak.",
            subtitle: "Cook daily, track your progress, and keep the flame alive. Your streak starts the moment you make your first meal."
        ),
    ]

    var body: some View {
        ZStack {
            LiquidCreamBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { idx, p in
                        pageView(p)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: page)

                bottomBar
                    .padding(.horizontal, 28)
                    .padding(.bottom, 52)
            }
        }
    }

    private func pageView(_ p: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(p.iconColor.opacity(0.15))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(p.iconColor.opacity(0.1))
                    .frame(width: 180, height: 180)
                Image(systemName: p.icon)
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(p.iconColor)
            }

            VStack(spacing: 16) {
                Text(p.title)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(p.subtitle)
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 40)

            Spacer()
            Spacer()
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 24) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == page ? Color.black.opacity(0.75) : Color.black.opacity(0.15))
                        .frame(width: idx == page ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: page)
                }
            }

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Start cooking →")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.black.opacity(0.82),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if page < pages.count - 1 {
                Button("Skip") { onFinish() }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.35))
            } else {
                Color.clear.frame(height: 22)
            }
        }
    }
}

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
}

#Preview {
    OnboardingView(onFinish: {})
}
