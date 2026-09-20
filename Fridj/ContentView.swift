import SwiftUI

enum AppTab: Int {
    case home, scan, recipes, bookmarks, cookbook
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @Bindable private var celebration = CelebrationCoordinator.shared
    @Bindable private var subscription = SubscriptionManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    // Local mirror of hasSeenOnboarding so the branch swap goes through a
    // proper @State change (AppStorage writes don't reliably animate).
    @State private var showOnboarding: Bool = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @Environment(\.scenePhase) private var scenePhase
    // A meal that arrived via a shared Frij link — saved on arrival, then
    // opened so the recipient sees what they just received.
    @State private var receivedRecipe: Recipe?
    // Invite prompts: "a friend sent you a code" on an early launch, and the
    // occasional "invite a friend" after a cook. Both live at the root so they
    // work no matter which tab the user was on.
    @Bindable private var inviteNudge = InviteNudge.shared
    @State private var showRedeemInvite = false

    var body: some View {
        ZStack {
            if showOnboarding {
                OnboardingView {
                    // Persist first, then animate the branch swap.
                    hasSeenOnboarding = true
                    withAnimation(.smooth(duration: 0.6)) {
                        showOnboarding = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
                .zIndex(1)
            } else {
                mainAppLayer
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            }
        }
    }

    @ViewBuilder
    private var mainAppLayer: some View {
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
                if selectedTab == .cookbook {
                    CookbookView()
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)

            ExpandableTabBar(selectedTab: $selectedTab)
                .phoneColumn()
                .padding(.bottom, 24)
                // Duolingo-style swipe-down when the camera panel is open.
                .offset(y: ScanSession.shared.hidesTabBar ? 180 : 0)
                .opacity(ScanSession.shared.hidesTabBar ? 0 : 1)
                .allowsHitTesting(!ScanSession.shared.hidesTabBar)

            // While the recipes sheet is presented it mounts its own copy (a
            // base-window overlay renders BEHIND sheets); skip the base mount
            // so the celebration never double-renders.
            if celebration.isShowing && !ScanSession.shared.showRecipes {
                StreakCelebrationView()
                    .zIndex(999)
            }
        }
        // Present paywall whenever any feature triggers it.
        .sheet(isPresented: $subscription.showPaywall) {
            PaywallView()
        }
        // A shared meal link: save it, cross-check it against THIS user's
        // pantry, and open it. Universal links arrive TWO ways and we must
        // handle both: onOpenURL fires when the app is already running, but a
        // COLD launch from tapping the link (the recipient's usual case)
        // delivers the URL via NSUserActivity — which only onContinueUserActivity
        // catches. Listening to just one silently drops the other.
        .onOpenURL { url in
            // frij://scan — the home-screen widget. Its whole promise is one
            // tap to the camera, so jump straight there rather than dropping
            // the user on whatever tab they left open.
            if url.scheme == "frij" {
                if url.host == "scan" || url.path == "/scan" { selectedTab = .scan }
                return
            }
            openSharedMeal(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { openSharedMeal(url) }
        }
        .sheet(item: $receivedRecipe) { recipe in
            RecipeDetailSheet(recipe: recipe) {
                receivedRecipe = nil
            }
        }
        // "Got a code from a friend?" — offered once, early, and only when the
        // clipboard plausibly holds one. The actual pasteboard READ happens
        // inside, behind the button, because iOS prompts on any read.
        .sheet(isPresented: $showRedeemInvite) {
            RedeemInvitePrompt { showRedeemInvite = false }
                .presentationDetents([.height(400)])
        }
        // The post-cook invite nudge. Rate-limited in InviteNudge (2nd cook,
        // then every 5th) so it stays a suggestion rather than a nag.
        .sheet(isPresented: $inviteNudge.isShowing) {
            NavigationStack { InviteView() }
        }
        .task {
            // Don't interrupt onboarding, and never ask someone who already
            // accepted an invite.
            guard !showOnboarding, !InviteStore.shared.hasRedeemed else { return }
            if await InviteStore.shared.hasCandidateCode() {
                try? await Task.sleep(nanoseconds: 900_000_000)
                showRedeemInvite = true
            }
        }
        // Re-verify subscription on every foreground.
        // This catches refunds, expirations, and family-sharing changes.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await SubscriptionManager.shared.refreshStatus() }
                // Recipes shared to Frij while we weren't running land in the
                // App Group inbox — import them now.
                Task { await ImportInbox.processPending() }
            }
        }
        // Lower the keyboard smoothly when switching tabs, rather than letting it
        // get cut off as the page swaps out.
        .onChange(of: selectedTab) { _, _ in
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    // Decode a shared-meal link, save it to Favorites (deduped), and open it.
    // Called from BOTH onOpenURL (warm) and onContinueUserActivity (cold launch).
    private func openSharedMeal(_ url: URL) {
        guard let recipe = RecipeShareLink.decode(from: url) else { return }
        if !FavoritesStore.shared.isFavorite(recipe) {
            _ = FavoritesStore.shared.toggle(recipe)
        }
        receivedRecipe = recipe
    }
}

#Preview {
    ContentView()
}
