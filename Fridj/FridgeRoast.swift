import SwiftUI

// The "Fridge Roast" share card: a playful, 100%-local rating of the user's
// fridge plus the three dinners Frij found anyway — rendered as a 9:16 image
// and handed to the system share sheet. The voice scales with the score
// (self-deprecating roast for sad fridges, warm-cheeky for workhorses, a flex
// for stocked ones) because roasting a beautiful fridge feels forced and
// congratulating half an onion misses the joke. Zero API calls, deterministic.
struct FridgeScore {
    let score: Int          // 1...10
    let line: String        // the roast / flex

    static func compute(names: [String]) -> FridgeScore {
        let categories = names.map { PantryCategory.classify($0) }
        let count = names.count
        let produce = categories.filter { $0 == .produce }.count
        let staples = categories.filter { $0 == .staples }.count
        let staplesShare = count > 0 ? Double(staples) / Double(count) : 0

        // Base: having food at all (capped). Diversity: one point per real
        // food group present. Trap: a fridge that's mostly condiments and dry
        // staples isn't dinner, whatever the count says.
        var score = min(count, 5)
        for group in [PantryCategory.produce, .protein, .dairy, .staples]
        where categories.contains(group) {
            score += 1
        }
        if staplesShare > 0.5 { score -= 2 }
        // No protein at all caps you out of the flex tier — cake, condiments
        // and a watermelon is not a chef's-kiss fridge.
        if !categories.contains(.protein) { score = min(score, 7) }
        score = max(1, min(10, score))

        return FridgeScore(score: score, line: line(score: score, count: count,
                                                    produce: produce, staplesShare: staplesShare))
    }

    private static func line(score: Int, count: Int, produce: Int, staplesShare: Double) -> String {
        switch score {
        case ...4:   // the sad fridge — playful-mean
            if staplesShare > 0.5 { return "Mostly condiments and commitment issues. Frij still found 3 dinners." }
            if produce == 0 { return "Not a single vegetable in sight. Frij still found 3 dinners." }
            return "\(count) items and a dream. Frij still found 3 dinners."
        case 5...7:  // the workhorse — warm-cheeky
            if produce == 0 { return "Solid stock — just allergic to green things. We can work with this." }
            if staplesShare >= 0.4 { return "Heavy on sauces, lighter on fresh. We can definitely work with this." }
            return "A respectable workhorse fridge. Plenty to cook with."
        default:     // the chef's kiss — playful flex
            if produce >= 4 { return "\(count) items, \(produce) of them fresh. Look at you adulting." }
            return "Stocked, diverse, zero sad produce. Chef's kiss."
        }
    }
}

// The 9:16 story-ready card. Kept to Frij's own design language: cream, big
// rounded type, one accent. Rendered offscreen via ImageRenderer.
struct FridgeRoastCard: View {
    let score: FridgeScore
    let dishes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FRIDGE SCORE")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .tracking(2.2)
                .foregroundStyle(.black.opacity(0.4))
                .padding(.top, 84)

            Text("\(score.score)/10")
                .font(.system(size: 118, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.fridjOrange)
                .padding(.top, 2)

            Text(score.line)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.82))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)

            Rectangle()
                .fill(.black.opacity(0.08))
                .frame(height: 1)
                .padding(.vertical, 30)

            Text("3 dinners Frij unlocked anyway")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.4))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(dishes.prefix(3), id: \.self) { dish in
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.fridjOrange)
                        Text(dish)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .padding(.top, 14)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "refrigerator.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("frij.app — cook what you have")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.black.opacity(0.35))
            .padding(.bottom, 56)
        }
        .padding(.horizontal, 44)
        .frame(width: 405, height: 720, alignment: .leading)
        .background(Color.fridjBg)
    }

    /// Render at 3x for a crisp 1215x2160 share image.
    @MainActor
    static func renderImage(score: FridgeScore, dishes: [String]) -> UIImage? {
        let renderer = ImageRenderer(content: FridgeRoastCard(score: score, dishes: dishes))
        renderer.scale = 3
        return renderer.uiImage
    }
}

// Minimal UIKit bridge to the system share sheet.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
