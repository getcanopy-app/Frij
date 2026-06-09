import SwiftUI

// Replaces CustomTabBar in ContentView.
// When a scan completes and ScanSession.showScanFound is true,
// the glass pill expands upward and its content morphs from tab icons → found panel.
struct ExpandableTabBar: View {
    @Binding var selectedTab: AppTab
    @Bindable private var session = ScanSession.shared
    @State private var store = PantryStore.shared

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
                    onContinue: {
                        // Simple path: close the panel and take the user straight
                        // to their dinner ideas. No intermediate Overview page.
                        session.showScanFound = false
                        session.cook(ingredients: store.allNames)
                        selectedTab = .recipes
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
                            selectedTab = item.tab
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: selectedTab == item.tab ? item.selectedIcon : item.icon)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(selectedTab == item.tab ? .primary : .secondary)
                                    .scaleEffect(selectedTab == item.tab ? 1.15 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selectedTab)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        }
                    }
                }
                .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            }
        }
        // Glass effect with a dark tint when expanded — gives Ardalan's mock contrast.
        // Collapsed pill keeps its light/neutral glass for the standard tab bar look.
        .glassEffect(
            isExpanded
                ? .regular.tint(Color.black.opacity(0.55))
                : .regular,
            in: .rect(cornerRadius: isExpanded ? 28 : 40)
        )
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: isExpanded)
        // When the user leaves the scan tab, collapse the panel so it doesn't
        // linger when they return.
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
    let onContinue: () -> Void
    let onDismiss: () -> Void

    // The items that actually got added to the pantry are the high-confidence ones.
    private var addedCount: Int {
        detected.filter { $0.confidence == .high }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                    Text("We found")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.white.opacity(0.18), in: Circle())
                }
            }

            // Two-column ingredient list
            let halves = splitHalves(detected)
            HStack(alignment: .top, spacing: 0) {
                ingredientColumn(halves.0)
                ingredientColumn(halves.1)
            }

            // "Added to pantry" confirmation
            if addedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.green)
                    Text("Added \(addedCount) to your pantry")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // Footer: count + continue (to recipes)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("x\(detected.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("ingredients detected")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Button(action: onContinue) {
                    HStack(spacing: 6) {
                        Text("Get dinners")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 48)
                    .background(Color.fridjOrange, in: Capsule())
                }
            }
        }
        .padding(20)
    }

    private func ingredientColumn(_ items: [DetectedItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                Text("• \(item.item.capitalized)")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func splitHalves(_ items: [DetectedItem]) -> ([DetectedItem], [DetectedItem]) {
        let mid = (items.count + 1) / 2
        return (Array(items.prefix(mid)), Array(items.dropFirst(mid)))
    }
}
