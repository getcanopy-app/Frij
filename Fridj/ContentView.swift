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
                case .bookmarks: BookmarksView()
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

    private let items: [(icon: String, tab: AppTab)] = [
        ("house",                 .home),
        ("viewfinder",            .scan),
        ("list.bullet.rectangle", .recipes),
        ("bookmark",              .bookmarks)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab.rawValue) { item in
                Button {
                    selectedTab = item.tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selectedTab == item.tab ? item.icon + ".fill" : item.icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(selectedTab == item.tab ? .primary : .secondary)
                            .symbolEffect(.bounce, value: selectedTab == item.tab)
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
