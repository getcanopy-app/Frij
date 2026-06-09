import SwiftUI

enum AppTab: Int {
    case home, scan, recipes, bookmarks
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @Bindable private var celebration = CelebrationCoordinator.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main content fills the whole screen (so the fridge photo can go
            // full-bleed during scan/review).
            Group {
                switch selectedTab {
                case .home:      HomeView(onScanTap: { selectedTab = .scan })
                case .scan:      ScanView()
                case .recipes:   RecipesView()
                case .bookmarks: PantryView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)  // only the content ignores safe area

            // The tab bar stays WITHIN the safe area and is constrained to the
            // screen width, so neither the collapsed pill nor the expanded
            // "We found" panel bleeds past the iPhone's rounded edges.
            ExpandableTabBar(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.bottom, 8)

            if celebration.isShowing {
                StreakCelebrationView()
                    .zIndex(999)
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    private let items: [(icon: String, selectedIcon: String, tab: AppTab)] = [
        ("house",                 "house.fill",                 .home),
        ("viewfinder",            "viewfinder",                 .scan),
        ("list.bullet.rectangle", "list.bullet.rectangle.fill", .recipes),
        ("refrigerator",          "refrigerator",               .bookmarks)
    ]

    var body: some View {
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
        .glassEffect(in: .rect(cornerRadius: 40))
    }
}

#Preview {
    ContentView()
}
