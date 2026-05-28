import SwiftUI

struct BookmarksView: View {
    var body: some View {
        ZStack {
            Color.fridjBg.ignoresSafeArea()
            VStack(spacing: FridjSpacing.md) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.fridjOrange)
                Text("Saved Recipes")
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
    BookmarksView()
}
