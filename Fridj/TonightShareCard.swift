import SwiftUI

// The shareable "Tonight's dinners" card: a designed one-page PDF of the
// current three dishes with their ingredients — the thing you actually send
// to a partner or pin to the fridge. Rendered as a real vector PDF (crisp
// text at any zoom, tiny file) via ImageRenderer's render(context:) path.

// Identifiable wrapper so the share sheet uses the battle-tested
// .sheet(item:) presentation (same pattern as the recipe detail sheet).
struct ShareDoc: Identifiable {
    let id = UUID()
    let url: URL
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

                    // Ingredients as a wrapping row of quiet chips. Amounts
                    // whisper; items still to buy get an orange dot.
                    let all = ingredientChips(recipe)
                    FlowLayout(spacing: 5) {
                        ForEach(Array(all.shown.enumerated()), id: \.offset) { _, chip in
                            HStack(spacing: 4) {
                                if chip.toBuy {
                                    Circle().fill(Color.fridjOrange).frame(width: 5, height: 5)
                                }
                                Text(chip.name)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.black.opacity(0.75))
                                if let amount = chip.amount {
                                    Text(amount)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(.black.opacity(0.4))
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.white, in: Capsule())
                        }
                        if all.overflow > 0 {
                            Text("+\(all.overflow) more")
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black.opacity(0.4))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                        }
                    }
                }
                .padding(.top, index == 0 ? 22 : 18)
            }

            HStack(spacing: 5) {
                Circle().fill(Color.fridjOrange).frame(width: 5, height: 5)
                Text("= still to buy")
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.4))
            }
            .padding(.top, 16)

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

    private struct Chip { let name: String; let amount: String?; let toBuy: Bool }
    private func ingredientChips(_ recipe: Recipe) -> (shown: [Chip], overflow: Int) {
        let split = PantryMatch.partition(recipe.uses + recipe.needs)
        let chips = split.have.map { item -> Chip in
            let p = PantryMatch.displaySplit(item)
            return Chip(name: p.name, amount: p.amount, toBuy: false)
        } + split.need.map { item -> Chip in
            let p = PantryMatch.displaySplit(item)
            return Chip(name: p.name, amount: p.amount, toBuy: true)
        }
        let cap = 10
        return (Array(chips.prefix(cap)), max(0, chips.count - cap))
    }

    /// Render to a real one-page PDF in the temp directory.
    @MainActor
    static func renderPDF(recipes: [Recipe]) -> URL? {
        let renderer = ImageRenderer(content: TonightShareCard(recipes: recipes))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Frij-Tonight.pdf")
        var rendered = false
        renderer.render { size, render in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let ctx = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }
            ctx.beginPDFPage(nil)
            render(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            rendered = true
        }
        return rendered ? url : nil
    }
}
