import SwiftUI

struct RecipesView: View {
    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()
            VStack(spacing: FridjSpacing.md) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 64))
                    .foregroundColor(.fridjOrange)
                Text("Recipes")
                    .font(FridjFont.style(.title2, weight: .bold))
                    .foregroundColor(.fridjText)
                Text("Coming soon")
                    .font(FridjFont.size(14))
                    .foregroundColor(.fridjText.opacity(0.4))
            }
        }
    }
}

#Preview {
    RecipesView()
}
