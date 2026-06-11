import SwiftUI

struct HomeView: View {
    var onScanTap: (() -> Void)? = nil
    @State private var showProfile = false
    @State private var selectedRecipe: Recipe?
    @Bindable private var session = ScanSession.shared

    private var recipes: [Recipe] { session.recipes }

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
        Group {
            if recipes.isEmpty {
                emptyRecipeCard
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recipes) { recipe in
                            Button {
                                selectedRecipe = recipe
                            } label: {
                                RecipeGlassCard(recipe: recipe)
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
            }
        }
    }

    private var emptyRecipeCard: some View {
        Button { onScanTap?() } label: {
            HStack(spacing: 14) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.black.opacity(0.35))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan your kitchen")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.75))
                    Text("Get tonight's dinner ideas")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.black.opacity(0.4))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .glassEffect(in: .rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
    }

    private var progressSection: some View {
        let cooking = CookingStore.shared
        let calendar = Calendar.current
        let today = Date()
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
                    Text(recipe.cookTime)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.black.opacity(0.42))

                    Spacer()

                    if !recipe.needs.isEmpty {
                        Text("needs \(recipe.needs.count) item\(recipe.needs.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange.opacity(0.85))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
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
