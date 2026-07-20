import SwiftUI

struct HomeView: View {
    var onScanTap: (() -> Void)? = nil
    @State private var showProfile = false
    @State private var selectedRecipe: Recipe?
    @Bindable private var session = ScanSession.shared

    private var recipes: [Recipe] { session.recipes }

    // Example dinners shown before the first scan, so Home previews the
    // populated layout instead of sitting empty. Rendered with the real
    // RecipeGlassCard so they show actual food photos; tapping starts a scan.
    static let teaserRecipes: [Recipe] = [
        Recipe(name: "Creamy Garlic Pasta", cookTime: "20 min", uses: [], needs: [], steps: []),
        Recipe(name: "Honey Garlic Chicken", cookTime: "30 min", uses: [], needs: [], steps: []),
        Recipe(name: "Veggie Stir-Fry", cookTime: "15 min", uses: [], needs: [], steps: [])
    ]

    var body: some View {
        ZStack {
            LiquidCreamBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                greeting
                    .padding(.top, 18)

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
        .sheet(item: $selectedRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe) {
                selectedRecipe = nil
            }
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

            Color.clear
                .frame(width: 22, height: 22)
        }
        .padding(.top, 16)
    }

    private var timeGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeGreeting)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.fridjOrange)
            Text("What's in your fridge?")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scanBar: some View {
        HStack {
            Text("Scan")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fridjDark)

            Spacer()

            Button { onScanTap?() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.fridjOrange)
                    .frame(width: 52, height: 42)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.92))
                    }
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .frame(height: 66)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.fridjPeach, Color.fridjOrange],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        }
        .shadow(color: Color.fridjOrange.opacity(0.35), radius: 18, x: 0, y: 10)
    }

    private var recipeCards: some View {
        Group {
            if recipes.isEmpty {
                emptyRecipeCard
                    .transition(.opacity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(recipes.enumerated()), id: \.element.id) { index, recipe in
                            Button {
                                selectedRecipe = recipe
                            } label: {
                                RecipeGlassCard(recipe: recipe)
                                    .frame(width: 245)
                            }
                            .buttonStyle(.plain)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(x: 20)),
                                removal: .opacity
                            ))
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.06),
                                value: recipes.count
                            )
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .padding(.horizontal, -20)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: recipes.isEmpty)
    }

    private var emptyRecipeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tonight you could make")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.5))
                .padding(.leading, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(HomeView.teaserRecipes) { teaser in
                        Button { onScanTap?() } label: {
                            RecipeGlassCard(recipe: teaser)
                                .frame(width: 245)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.horizontal, -20)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("Scan your fridge to make these real")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundStyle(.black.opacity(0.4))
            .padding(.leading, 2)
            .padding(.top, 2)
        }
    }

    private var progressSection: some View {
        let cooking = CookingStore.shared
        let calendar = Calendar.current
        let today = Date()
        // Anchor on the most recent Sunday regardless of locale's firstWeekday,
        // so weekDates[0] always matches the "Su" label.
        let weekdayIndex = calendar.component(.weekday, from: today) - 1 // 0=Sun … 6=Sat
        let weekStart = calendar.date(byAdding: .day, value: -weekdayIndex, to: today)!
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
                        .fill(LinearGradient(
                            colors: [.orange, .yellow.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
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
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MealImageView(dish: recipe.name, cornerRadius: 0)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipShape(.rect(topLeadingRadius: 26, topTrailingRadius: 26))

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.82))
                    .lineLimit(2)
                    .lineSpacing(2)

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11, weight: .semibold))
                        Text(recipe.cookTime)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(.black.opacity(0.45))

                    Spacer()

                    if !recipe.needs.isEmpty {
                        Text("needs \(recipe.needs.count) item\(recipe.needs.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.fridjOrange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.fridjOrange.opacity(0.14)))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .shadow(color: .black.opacity(0.09), radius: 13, x: 0, y: 6)
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
