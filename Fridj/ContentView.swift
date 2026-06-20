import SwiftUI

enum AppTab: Int {
    case home, scan, recipes, bookmarks
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @Bindable private var celebration = CelebrationCoordinator.shared
    @Bindable private var subscription = SubscriptionManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if !hasSeenOnboarding {
            OnboardingView {
                hasSeenOnboarding = true
            }
        } else {
        ZStack(alignment: .bottom) {
            ZStack {
                if selectedTab == .home {
                    HomeView(onScanTap: {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                            selectedTab = .scan
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 10)),
                        removal: .opacity
                    ))
                }
                if selectedTab == .scan {
                    ScanView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                }
                if selectedTab == .recipes {
                    RecipesView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                }
                if selectedTab == .bookmarks {
                    PantryView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)

            ExpandableTabBar(selectedTab: $selectedTab)
                .padding(.bottom, 24)

            if celebration.isShowing {
                StreakCelebrationView()
                    .zIndex(999)
            }
        }
        // Present paywall whenever any feature triggers it.
        .sheet(isPresented: $subscription.showPaywall) {
            PaywallView()
        }
        // Re-verify subscription on every foreground.
        // This catches refunds, expirations, and family-sharing changes.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await SubscriptionManager.shared.refreshStatus() }
            }
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
