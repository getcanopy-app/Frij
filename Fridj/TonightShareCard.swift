import SwiftUI

// The shareable "Tonight's dinners" card: a designed one-page PDF of the
// current three dishes with their ingredients — the thing you actually send
// to a partner or pin to the fridge. Rendered as a real vector PDF (crisp
// text at any zoom, tiny file) via ImageRenderer's render(context:) path.

// Identifiable wrapper so the share sheet uses the battle-tested
// .sheet(item:) presentation (same pattern as the recipe detail sheet).
struct ShareDoc: Identifiable {
    let id = UUID()
    let items: [Any]

    /// Build clean share items from a rendered card and an optional link.
    /// A raw UIImage passed to the share sheet gets serialized into an ugly
    /// `bplist00…` text blob by Messages/Mail; writing the image to a temp PNG
    /// FILE and sharing its URL makes it attach as a proper inline image.
    @MainActor
    static func meal(image: UIImage, link: URL?, name: String) -> ShareDoc {
        var items: [Any] = []
        if let data = image.pngData() {
            let safe = name.replacingOccurrences(of: "/", with: "-")
                           .replacingOccurrences(of: ":", with: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(safe.isEmpty ? "meal" : safe).png")
            if (try? data.write(to: url)) != nil {
                items.append(url)
            } else {
                items.append(image)   // fallback: still shares, just less clean
            }
        } else {
            items.append(image)
        }
        if let link { items.append(link) }
        return ShareDoc(items: items)
    }
}

struct TonightShareCard: View {
    let recipes: [Recipe]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("TONIGHT'S DINNERS")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(.black.opacity(0.4))
            Text("From what's in the kitchen")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.black.opacity(0.85))
                .padding(.top, 2)

            ForEach(Array(recipes.prefix(3).enumerated()), id: \.element.id) { index, recipe in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(index + 1).")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.fridjOrange)
                        Text(recipe.name)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.85))
                        Spacer()
                        if !recipe.cookTime.isEmpty {
                            Text(recipe.cookTime)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.fridjGreen)
                        }
                    }

                    // Ingredients as one quiet wrapping line — just what the
                    // meal needs. No fridge status (private to the sender), and
                    // no FlowLayout: ImageRenderer can't render that custom
                    // layout, which returned nil and made the share button do
                    // nothing.
                    let names = ingredientNames(recipe)
                    if !names.isEmpty {
                        Text(names.joined(separator: "  ·  "))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, index == 0 ? 22 : 18)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Frij — cook what you have")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.black.opacity(0.35))
        }
        .padding(38)
        .frame(width: 612, height: 792, alignment: .topLeading)   // US Letter
        .background(Color.fridjBg)
    }

    // Just the ingredient names the meal needs — deduped, capped so the card
    // stays tidy. No have/need split (that would reveal the sender's fridge).
    private func ingredientNames(_ recipe: Recipe) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for item in recipe.uses + recipe.needs {
            let name = PantryMatch.displaySplit(item).name
            if seen.insert(name.lowercased()).inserted { out.append(name) }
        }
        return Array(out.prefix(12))
    }

    /// Render the card as a crisp 3x image.
    @MainActor
    static func renderImage(recipes: [Recipe]) -> UIImage? {
        let renderer = ImageRenderer(content: TonightShareCard(recipes: recipes))
        renderer.scale = 3
        return renderer.uiImage
    }
}

// A single meal as a shareable card that mirrors the in-app recipe sheet:
// hero photo, mint time pill, grouped IN YOUR FRIDGE / TO BUY ingredient
// rows, green-circle steps. Page is phone-card proportioned (fixed width,
// natural height) so the PDF *is* the card, just crisper.
struct RecipeShareCard: View {
    let recipe: Recipe
    let heroImage: UIImage?

    private let pageWidth: CGFloat = 430

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero photo — the same star it is in the app.
            Group {
                if let heroImage {
                    Image(uiImage: heroImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Color.fridjText.opacity(0.06)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(Color.fridjText.opacity(0.25))
                    }
                }
            }
            .frame(width: pageWidth - 56, height: 240)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(recipe.name)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(Color.fridjText)
                .padding(.top, 18)

            HStack(spacing: 8) {
                if !recipe.cookTime.isEmpty {
                    Text(recipe.cookTime)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.fridjGreen)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.fridjMint.opacity(0.5), in: Capsule())
                }
                if let origin = recipe.origin {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.system(size: 11, weight: .bold))
                        Text("From \(origin)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color.fridjOrange)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.fridjOrange.opacity(0.12), in: Capsule())
                }
            }
            .padding(.top, 10)

            // Ingredients — a PLAIN list of everything the meal needs. The
            // shared image must NOT reveal the sender's pantry (no "in your
            // fridge / to buy"): the recipient's own app splits have-vs-need
            // against THEIR kitchen when they open the link.
            let allIngredients = recipe.uses + recipe.needs
            if !allIngredients.isEmpty {
                Text("Ingredients")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.fridjText)
                    .padding(.top, 22)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(allIngredients, id: \.self) { item in
                        let parts = PantryMatch.displaySplit(item)
                        HStack(spacing: 9) {
                            Circle().fill(Color.fridjOrange.opacity(0.55))
                                .frame(width: 5, height: 5)
                            Text(parts.name)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundStyle(Color.fridjText)
                            if let amount = parts.amount {
                                Text(amount)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.fridjText.opacity(0.4))
                            }
                        }
                    }
                }
                .padding(.top, 11)
            }

            // Steps — the same handwritten notepad card the app now shows.
            if !recipe.steps.isEmpty {
                let ink = Color(hex: "4A3A28")
                VStack(alignment: .leading, spacing: 0) {
                    Text("How to make it")
                        .font(.custom("Bradley Hand", size: 23).weight(.bold))
                        .foregroundColor(ink)
                        .padding(.bottom, 2)
                    Rectangle()
                        .fill(Color.fridjOrange.opacity(0.35))
                        .frame(width: 140, height: 2)
                        .padding(.bottom, 16)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(idx + 1).")
                                    .font(.custom("Bradley Hand", size: 18).weight(.bold))
                                    .foregroundColor(.fridjCoral)
                                    .frame(width: 24, alignment: .leading)
                                Text(step)
                                    .font(.system(size: 15, weight: .regular, design: .serif))
                                    .foregroundColor(ink.opacity(0.9))
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 11)
                            if idx < recipe.steps.count - 1 {
                                Rectangle().fill(ink.opacity(0.1)).frame(height: 1)
                            }
                        }
                    }
                }
                .padding(.leading, 22).padding(.trailing, 18).padding(.vertical, 18)
                .background(
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(hex: "FFFDF4"))
                        Rectangle()
                            .fill(Color.fridjCoral.opacity(0.4))
                            .frame(width: 1.5)
                            .padding(.leading, 14).padding(.vertical, 10)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(ink.opacity(0.1), lineWidth: 1)
                )
                .padding(.top, 24)
            }

            HStack(spacing: 6) {
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text("Frij — cook what you have")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.fridjText.opacity(0.35))
            .padding(.top, 28)
        }
        .padding(28)
        .frame(width: pageWidth, alignment: .topLeading)
        .background(Color.fridjBg)
    }

    /// Fetch the dish photo (cache first), then render the card as a crisp
    /// 3x image — previews inline in iMessage, posts straight to stories.
    @MainActor
    static func renderImage(recipe: Recipe) async -> UIImage? {
        var hero: UIImage?
        let imageURL: URL?
        if let cached = MealImageCache.shared.url(for: recipe.name) {
            imageURL = cached
        } else {
            imageURL = try? await FrijAPI.mealImage(dish: recipe.name)
        }
        if let imageURL, let (data, _) = try? await URLSession.shared.data(from: imageURL) {
            hero = UIImage(data: data)
        }
        let renderer = ImageRenderer(content: RecipeShareCard(recipe: recipe, heroImage: hero))
        renderer.scale = 3
        return renderer.uiImage
    }
}
