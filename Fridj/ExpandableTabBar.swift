import SwiftUI

// Replaces CustomTabBar in ContentView.
// When a scan completes and ScanSession.showScanFound is true,
// the glass pill expands upward and its content morphs from tab icons → found panel.
struct ExpandableTabBar: View {
    @Binding var selectedTab: AppTab
    @Bindable private var session = ScanSession.shared
    @State private var store = PantryStore.shared
    @State private var grocery = GroceryStore.shared

    private let items: [(icon: String, selectedIcon: String, tab: AppTab)] = [
        ("house",                 "house.fill",                 .home),
        ("viewfinder",            "viewfinder",                 .scan),
        ("list.bullet.rectangle", "list.bullet.rectangle.fill", .recipes),
        ("refrigerator",          "refrigerator",               .bookmarks),
    ]

    private var isExpanded: Bool { selectedTab == .scan && session.showScanFound }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                FoundInlinePanel(
                    detected: session.scanDetectedItems,
                    onAdd: { item in
                        store.mergeScan([item])
                    },
                    onContinue: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                            session.showScanFound = false
                            session.cook(ingredients: store.allNames)
                            selectedTab = .recipes
                        }
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                            session.showScanFound = false
                        }
                    }
                )
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            } else {
                HStack(spacing: 0) {
                    ForEach(items, id: \.tab.rawValue) { item in
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                selectedTab = item.tab
                            }
                        } label: {
                            VStack(spacing: 4) {
                                ZStack(alignment: .topTrailing) {
                                    Image(systemName: selectedTab == item.tab ? item.selectedIcon : item.icon)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(selectedTab == item.tab ? .primary : .secondary)
                                        .scaleEffect(selectedTab == item.tab ? 1.15 : 1.0)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selectedTab)

                                    if item.tab == .bookmarks, grocery.uncheckedCount > 0 {
                                        Text("\(grocery.uncheckedCount)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(minWidth: 14, minHeight: 14)
                                            .background(Color.fridjOrange, in: Circle())
                                            .offset(x: 8, y: -6)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            }
        }
        // containerRelativeFrame computes an explicit pixel width at layout time
        // (unlike .frame(maxWidth: .infinity)), which is what glassEffect needs
        // to constrain its scene-level rendering.
        .containerRelativeFrame(.horizontal) { width, _ in width - 44 }
        .glassEffect(
            isExpanded
                ? .regular.tint(Color.black.opacity(0.55))
                : .regular,
            in: .rect(cornerRadius: isExpanded ? 28 : 40)
        )
        .clipShape(.rect(cornerRadius: isExpanded ? 28 : 40))
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: isExpanded)
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .scan && session.showScanFound {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                    session.showScanFound = false
                }
            }
        }
    }
}

// MARK: - Found inline panel (lives inside the expanded glass container)

struct FoundInlinePanel: View {
    let detected: [DetectedItem]
    let onAdd: (DetectedItem) -> Void
    let onContinue: () -> Void
    let onDismiss: () -> Void

    // Medium-confidence suggestions the user has tapped to add this session.
    @State private var accepted: Set<String> = []

    // High-confidence items were auto-merged into the pantry already; medium
    // ones are opt-in suggestions the user taps to add.
    private var autoAdded: [DetectedItem] { detected.filter { $0.confidence == .high } }
    private var suggestions: [DetectedItem] { detected.filter { $0.confidence == .medium } }
    private var addedCount: Int { autoAdded.count + accepted.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.yellow)
                    Text("We found \(detected.count) items")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 26, height: 26)
                }
            }

            // Auto-added (high-confidence) list
            if !autoAdded.isEmpty {
                Text(autoAdded.map { "• \($0.item.capitalized)" }.joined(separator: "  "))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Medium-confidence suggestions — tap a chip to add it to the pantry.
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Also spotted — tap to add")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions) { item in
                            suggestionChip(item)
                        }
                    }
                }
            }

            // Footer: status + continue button
            HStack(alignment: .center) {
                if addedCount > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.green)
                        Text("Added \(addedCount) to pantry")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                } else {
                    Text("ingredients detected")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Button(action: onContinue) {
                    HStack(spacing: 5) {
                        Text("Get dinners")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .background(Color.fridjOrange, in: Capsule())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func suggestionChip(_ item: DetectedItem) -> some View {
        let isAdded = accepted.contains(item.id)
        Button {
            guard !isAdded else { return }
            withAnimation(.easeOut(duration: 0.15)) { _ = accepted.insert(item.id) }
            onAdd(item)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isAdded ? "checkmark" : "plus")
                    .font(.system(size: 10, weight: .bold))
                Text(item.item.capitalized)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isAdded ? .white.opacity(0.5) : .white)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(isAdded ? Color.white.opacity(0.08) : Color.white.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(isAdded ? 0 : 0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }

}

// Left-to-right wrapping layout so chips hug their content and sit next to each
// other, wrapping to a new line only when they run out of width. Replaces a
// LazyVGrid, which spread a small number of chips across the full width (2 chips
// ended up at opposite edges with a big gap).
fileprivate struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                widestRow = max(widestRow, x - spacing)
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        widestRow = max(widestRow, x - spacing)
        totalHeight += rowHeight
        return CGSize(width: min(widestRow, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
