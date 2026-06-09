import SwiftUI

struct HomeView: View {
    var onScanTap: (() -> Void)? = nil
    @State private var showProfile = false

    var body: some View {
        ZStack {
            LiquidCreamBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                scanBar
                    .padding(.top, 16)

                recipeCards
                    .padding(.top, 20)

                progressSection
                    .padding(.top, 24)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 110)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                showProfile = true
            } label: {
                Image(systemName: "person.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.8))
            }

            Spacer()

            Text("Frij")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))

            Spacer()

            // Keep symmetry with the leading icon
            Color.clear
                .frame(width: 22, height: 22)
        }
        .padding(.top, 16)
    }

    private var scanBar: some View {
        HStack {
            Text("Scan")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Spacer()

            Button { onScanTap?() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 52, height: 42)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .frame(height: 66)
        .glassEffect(in: .rect(cornerRadius: 34))
    }

    private var recipeCards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 36) {
                RecipeGlassCard(
                    title: "Mediterranean breakfast bowl",
                    time: "~21 min",
                    difficulty: "Medium",
                    difficultyColor: .orange,
                    tint: Color(red: 0.72, green: 0.82, blue: 0.68)
                )
                .frame(width: 245)

                RecipeGlassCard(
                    title: "Avo Toast and\nEgg",
                    time: "~10 mins",
                    difficulty: "Easy",
                    difficultyColor: Color(red: 0.35, green: 0.65, blue: 0.52)
                )
                .frame(width: 245)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .padding(.horizontal, -20)
    }

    private var progressSection: some View {
        let cooking = CookingStore.shared
        let calendar = Calendar.current
        let today = Date()
        // Build the 7 dates for the current week (Sun–Sat)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        let weekDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        let labels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        let todayLabel = labels[calendar.component(.weekday, from: today) - 1]

        return VStack(alignment: .leading, spacing: 14) {
            Text("This week's progress")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))

            VStack(spacing: 10) {
                HStack {
                    ForEach(labels, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(day == todayLabel ? .orange : .black.opacity(0.45))
                            .frame(maxWidth: .infinity)
                    }
                }

                HStack {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { _, date in
                        let cooked = cooking.hasCooked(on: date)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(cooked ? 0.9 : 0.25))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 38)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .yellow.opacity(0.92)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.22))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.4), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 8)
            }
        }
    }
}

struct RecipeGlassCard: View {
    let title: String
    let time: String
    let difficulty: String
    let difficultyColor: Color
    var tint: Color? = nil

    @State private var photos = MealPhotoService.shared

    private let imageHeight: CGFloat = 200
    private let imageOverflow: CGFloat = 60
    private let cardHeight: CGFloat = 220

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.82))
                    .lineSpacing(2)

                HStack {
                    Text(time)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.42))

                    Spacer()

                    Text(difficulty)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(difficultyColor.opacity(0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
            .frame(height: cardHeight)
            .frame(maxWidth: .infinity)
            .glassEffect(tint.map { .regular.tint($0) } ?? .regular, in: .rect(cornerRadius: 26))
            .padding(.top, imageOverflow)

            AsyncImage(url: photos.urls[title]) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.black.opacity(0.06)
            }
            .frame(height: imageHeight)
            .clipShape(.rect(cornerRadius: 20))
            .padding(.horizontal, 10)
            .animation(.easeIn(duration: 0.25), value: photos.urls[title] != nil)
        }
        .frame(height: cardHeight + imageOverflow)
        .task { await photos.fetch(for: title) }
    }
}

struct LiquidCreamBackground: View {
    var body: some View {
        Image("FridjBackground")
            .resizable()
            .ignoresSafeArea()
    }
}

#Preview {
    HomeView()
}
