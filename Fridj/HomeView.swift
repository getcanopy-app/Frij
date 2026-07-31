import SwiftUI

struct HomeView: View {
    var onScanTap: (() -> Void)? = nil
    @State private var showProfile = false
    @State private var selectedRecipe: Recipe?
    @Bindable private var session = ScanSession.shared

    private var recipes: [Recipe] { session.recipes }

    // Example dinners shown before the first scan, so Home previews the
    // populated layout instead of sitting empty. Full recipes (steps + a
    // shopping list in `needs`) so tapping opens the same detail sheet as any
    // other meal — a card that looks like a recipe must act like one.
    static let teaserRecipes: [Recipe] = [
        Recipe(name: "Creamy Garlic Pasta", cookTime: "20 min", uses: [],
               needs: ["pasta", "garlic", "heavy cream", "parmesan"],
               steps: ["Boil the pasta in salted water until al dente.",
                       "Gently soften lots of sliced garlic in butter — don't brown it.",
                       "Pour in the cream and simmer 3–4 minutes until it coats a spoon.",
                       "Toss the pasta in with parmesan, loosening with pasta water.",
                       "Season and finish with parsley or pepper."]),
        Recipe(name: "Honey Garlic Chicken", cookTime: "30 min", uses: [],
               needs: ["chicken thighs", "honey", "soy sauce", "garlic", "rice"],
               steps: ["Sear seasoned chicken thighs until golden on both sides.",
                       "Stir together honey, soy sauce, and minced garlic.",
                       "Pour the sauce over the chicken; simmer until sticky and cooked through.",
                       "Spoon the glaze over the top.",
                       "Serve over rice."]),
        Recipe(name: "Veggie Stir-Fry", cookTime: "15 min", uses: [],
               needs: ["mixed vegetables", "soy sauce", "garlic", "ginger", "rice"],
               steps: ["Cook the rice first.",
                       "Get a pan screaming hot with a little oil.",
                       "Stir-fry the hardest vegetables first, softest last, with garlic and ginger.",
                       "Splash in soy sauce and toss until glossy.",
                       "Serve over rice."])
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

    // Personalized for $0 (no API call, no latency): recent generated dishes
    // when they exist — real recipes, taste-ranked, from the user's own pantry
    // — then day-one quiz picks (photos already cached from onboarding), and
    // the stock teasers only when we know nothing at all. Framing stays honest
    // per tier: past ideas are revisitable; aspirational ones say "scan to
    // make these real" so a preview never promises a dinner the fridge can't
    // back.
    private var recentIdeas: [Recipe] {
        Array(RecipeHistoryStore.shared.recipes.prefix(4))
    }

    private var quizTeasers: [Recipe] {
        TasteSignalsStore.shared.quizPicks.prefix(3).map { TasteQuiz.recipe(for: $0) }
    }

    private var emptyRecipeCard: some View {
        let recent = recentIdeas
        let quiz = quizTeasers
        let title = !recent.isEmpty ? "From your recent ideas"
                  : !quiz.isEmpty ? "Tuned to your taste"
                  : "Tonight you could make"

        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.5))
                .padding(.leading, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if !recent.isEmpty {
                        // Real recipes — tap opens the full detail sheet.
                        ForEach(recent) { recipe in
                            Button { selectedRecipe = recipe } label: {
                                RecipeGlassCard(recipe: recipe)
                                    .frame(width: 245)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        // Aspirational teasers (quiz picks or stock) — real
                        // recipes now, so tapping opens the detail sheet like
                        // every other meal card in the app. The caption below
                        // still points at scanning to make them real.
                        ForEach(quiz.isEmpty ? HomeView.teaserRecipes : quiz) { teaser in
                            Button { selectedRecipe = teaser } label: {
                                RecipeGlassCard(recipe: teaser)
                                    .frame(width: 245)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.horizontal, -20)

            if recent.isEmpty {
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

        let streak = cooking.currentStreak

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week's progress")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.82))
                Spacer()
                // The streak, finally visible where the week lives.
                if streak > 0 {
                    Text("🔥 \(streak)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.fridjOrange)
                }
            }

            // Seven articulated day coins instead of one solid loaf: cooked
            // days glow in a warm gradient that deepens across the week,
            // today-uncooked invites with a dashed ring, future days recede.
            HStack(spacing: 0) {
                ForEach(Array(weekDates.enumerated()), id: \.offset) { index, date in
                    let cooked = cooking.hasCooked(on: date)
                    let isToday = calendar.isDate(date, inSameDayAs: today)
                    let isFuture = date > today && !isToday

                    VStack(spacing: 7) {
                        Text(labels[index])
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(isToday ? Color.fridjOrange : .black.opacity(isFuture ? 0.25 : 0.45))

                        ZStack {
                            if cooked {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [
                                            Color(hue: 0.075 - Double(index) * 0.004, saturation: 0.82, brightness: 0.96),
                                            Color(hue: 0.11 + Double(index) * 0.004, saturation: 0.85, brightness: 0.98),
                                        ],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ))
                                    .shadow(color: Color.fridjOrange.opacity(0.35), radius: 5, x: 0, y: 2)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .heavy))
                                    .foregroundStyle(.white)
                            } else if isToday {
                                Circle()
                                    .strokeBorder(Color.fridjOrange.opacity(0.75),
                                                  style: StrokeStyle(lineWidth: 1.8, dash: [3.5, 3.5]))
                            } else {
                                Circle()
                                    .strokeBorder(Color.black.opacity(isFuture ? 0.08 : 0.14), lineWidth: 1.5)
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                    .frame(maxWidth: .infinity)
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

                    // LIVE against the current pantry (PantryMatch), never the
                    // stored split — buy the missing item and every card badge
                    // heals, matching what the detail sheet shows inside.
                    let missing = PantryMatch.partition(recipe.uses + recipe.needs).need.count
                    if missing > 0 {
                        Text("needs \(missing) item\(missing == 1 ? "" : "s")")
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
