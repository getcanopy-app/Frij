import SwiftUI

struct ProfileView: View {
    @State private var store = ProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.fridjBg.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: FridjSpacing.xl) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("About you")
                                .font(FridjFont.style(.title, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Frij uses this to make recipes that actually fit you.")
                                .font(FridjFont.size(14))
                                .foregroundColor(.fridjText.opacity(0.5))
                        }
                        .padding(.top, FridjSpacing.md)

                        // Diet
                        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                            Text("Dietary preferences")
                                .font(FridjFont.size(15, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Free text. \"High protein, no pork.\" \"Pescatarian.\" Whatever fits.")
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjText.opacity(0.5))
                            TextField("e.g. high protein, no pork", text: $store.profile.diet, axis: .vertical)
                                .lineLimit(2...4)
                                .font(FridjFont.size(15))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                        }

                        // Household
                        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                            Text("Cooking for")
                                .font(FridjFont.size(15, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Frij will scale recipe portions to match.")
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjText.opacity(0.5))
                            HStack(spacing: FridjSpacing.sm) {
                                ForEach(HouseholdSize.allCases) { size in
                                    Button {
                                        if store.profile.household == size {
                                            store.profile.household = nil  // tap again to deselect
                                        } else {
                                            store.profile.household = size
                                        }
                                    } label: {
                                        Text(size.label)
                                            .font(FridjFont.size(14, weight: .bold))
                                            .foregroundColor(store.profile.household == size ? .white : .fridjText.opacity(0.7))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                store.profile.household == size ? Color.fridjGreen : .white,
                                                in: RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: FridjRadius.sm, style: .continuous)
                                                    .stroke(Color.fridjText.opacity(store.profile.household == size ? 0 : 0.12), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }

                        // Dislikes
                        VStack(alignment: .leading, spacing: FridjSpacing.sm) {
                            Text("Things to avoid")
                                .font(FridjFont.size(15, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("Foods you hate, allergies, picky kid stuff — anything Frij should steer clear of.")
                                .font(FridjFont.size(13))
                                .foregroundColor(.fridjText.opacity(0.5))
                            TextField("e.g. no cilantro, no mushrooms", text: $store.profile.dislikes, axis: .vertical)
                                .lineLimit(2...4)
                                .font(FridjFont.size(15))
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .background(.white, in: RoundedRectangle(cornerRadius: FridjRadius.md, style: .continuous))
                        }
                    }
                    .padding(FridjSpacing.lg)
                    .padding(.bottom, FridjSpacing.xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(FridjFont.size(16, weight: .bold))
                        .foregroundColor(.fridjOrange)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
