import SwiftUI

enum AppTab: Int {
    case home, scan, recipes, bookmarks
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:      HomeView()
                case .scan:      ScanView()
                case .recipes:   RecipesView()
                case .bookmarks: PantryView()   // <- was BookmarksView (placeholder)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    // The fourth tab is now the pantry. Using a refrigerator icon since
    // that's what it represents. Ardalan can adjust the icon if he wants.
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
