import SwiftUI
import PhotosUI

// My Cookbook — a private journal of everything the user has actually cooked.
// Not social, not public, nothing to submit anywhere. The pull is that it's
// THEIRS and it fills up: every cook lands here whether or not they ever take
// a photo.

// It lives as a SECTION of the meals tab rather than a tab of its own: saved
// recipes and cooked meals are the same bucket ("my food"), and a fifth tab is
// how a one-job app stops feeling like one.
struct CookbookSection: View {
    @State private var cookbook = CookbookStore.shared
    @State private var cooking = CookingStore.shared
    @State private var selected: CookbookStore.Entry?

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("My Cookbook")
                .font(FridjFont.style(.title, weight: .bold))
                .foregroundColor(.fridjText)

            statCard

            ForEach(cookbook.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title)
                        .font(FridjFont.size(12, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(.fridjText.opacity(0.35))
                        .padding(.top, 4)
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(section.entries) { entry in
                            Button { selected = entry } label: { cell(entry) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .sheet(item: $selected) { entry in
            CookEntrySheet(entry: entry)
        }
    }

    // MARK: Stat card

    private var statCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(cookbook.mealsCooked)")
                    .font(FridjFont.size(38, weight: .heavy))
                    .foregroundColor(.fridjText)
                Text(cookbook.mealsCooked == 1 ? "meal cooked" : "meals cooked")
                    .font(FridjFont.size(17, weight: .bold))
                    .foregroundColor(Color(hex: "B07A42"))
            }
            Spacer(minLength: 8)
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.fridjOrange)
                    Text("\(cooking.currentStreak)")
                        .font(FridjFont.size(26, weight: .heavy))
                        .foregroundColor(.fridjOrange)
                }
                Text("DAY STREAK")
                    .font(FridjFont.size(11, weight: .heavy))
                    .tracking(0.6)
                    .foregroundColor(Color(hex: "B07A42"))
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.horizontal, 22).padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color.fridjPeach,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: Cell

    private func cell(_ entry: CookbookStore.Entry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FilledPhoto(height: 165) {
                if let photo = cookbook.photo(for: entry) {
                    Image(uiImage: photo).resizable()
                } else {
                    // No photo is a first-class state: the recipe's own picture
                    // stands in, so the grid never looks broken or half-done.
                    MealImageView(dish: entry.recipe.name,
                                  plate: entry.recipe.nutrition?.serving,
                                  cornerRadius: 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(entry.recipe.name)
                .font(FridjFont.size(16, weight: .bold))
                .foregroundColor(.fridjText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(CookbookStore.relativeDay(entry.cookedAt))
                .font(FridjFont.size(14, weight: .semibold))
                .foregroundColor(.fridjSage)
        }
    }
}

// MARK: - One cooked meal

/// Tapping a cell opens the cook itself: the photo (or the recipe's), the
/// caption they wrote, and the two things they might want now — add or replace
/// the photo, and share it again.
struct CookEntrySheet: View {
    let entry: CookbookStore.Entry

    @Environment(\.dismiss) private var dismiss
    @State private var cookbook = CookbookStore.shared
    @State private var pickedImage: UIImage?
    @State private var showCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showSourceChoice = false
    @State private var pickingLibrary = false
    @State private var shareDoc: ShareDoc?
    @State private var showRecipe = false

    private var current: CookbookStore.Entry { cookbook.entry(entry.id) ?? entry }

    var body: some View {
        VStack(spacing: 0) {
            header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        FilledPhoto(height: 320) {
                            if let photo = cookbook.photo(for: current) {
                                Image(uiImage: photo).resizable()
                            } else {
                                MealImageView(dish: current.recipe.name,
                                              plate: current.recipe.nutrition?.serving,
                                              cornerRadius: 0)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(current.recipe.name)
                                .font(FridjFont.size(24, weight: .bold))
                                .foregroundColor(.fridjText)
                            Text("\(current.recipe.cookTime) · \(CookbookStore.relativeDay(current.cookedAt))")
                                .font(FridjFont.size(15, weight: .semibold))
                                .foregroundColor(.fridjText.opacity(0.45))
                            if let caption = current.caption {
                                Text(caption)
                                    .font(FridjFont.size(16))
                                    .foregroundColor(.fridjText.opacity(0.8))
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        actions
                    }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(Color.fridjBg.ignoresSafeArea())
        .fullScreenCover(isPresented: $showCamera) {
            PlateCameraPicker { pickedImage = $0 }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $pickingLibrary, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) { pickedImage = image }
                photoItem = nil
            }
        }
        .fullScreenCover(item: Binding(
            get: { pickedImage.map { KeepsakePayload(image: $0) } },
            set: { if $0 == nil { pickedImage = nil } })
        ) { payload in
            KeepsakeView(entry: current, image: payload.image)
        }
        .confirmationDialog("Add a photo", isPresented: $showSourceChoice) {
            Button("Take a photo") { showCamera = true }
            Button("Choose from library") { pickingLibrary = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $shareDoc) { doc in
            ShareSheet(items: doc.items).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showRecipe) {
            RecipeDetailSheet(recipe: current.recipe) {}
        }
        .presentationBackground(Color.fridjBg)
    }

    private var header: some View {
        ZStack {
            Text(CookbookStore.shortDateFormatter.string(from: current.cookedAt))
                .font(FridjFont.size(17, weight: .bold))
                .foregroundColor(.fridjText.opacity(0.6))
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.fridjText.opacity(0.5))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { showSourceChoice = true } label: {
                HStack(spacing: 9) {
                    Image(systemName: "camera.fill").font(.system(size: 16, weight: .bold))
                    Text(current.photoFile == nil ? "Add a photo" : "Replace photo")
                        .font(FridjFont.size(16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.fridjSage,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button { shareCook() } label: {
                    outlineLabel(icon: "square.and.arrow.up", title: "Share")
                }
                .buttonStyle(.plain)
                .disabled(cookbook.photo(for: current) == nil)
                .opacity(cookbook.photo(for: current) == nil ? 0.4 : 1)

                Button { showRecipe = true } label: {
                    outlineLabel(icon: "book", title: "Recipe")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func outlineLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold))
            Text(title).font(FridjFont.size(16, weight: .bold))
        }
        .foregroundColor(.fridjText)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.fridjText.opacity(0.15), lineWidth: 1)
        )
    }

    private func shareCook() {
        guard let photo = cookbook.photo(for: current) else { return }
        Task {
            guard let card = await KeepsakeCard.renderImage(
                recipe: current.recipe, image: photo, cookedAt: current.cookedAt) else { return }
            shareDoc = ShareDoc.meal(image: card,
                                     link: RecipeShareLink.url(for: current.recipe),
                                     name: current.recipe.name)
        }
    }
}

/// Identifiable wrapper so a freshly picked photo can drive .fullScreenCover(item:).
struct KeepsakePayload: Identifiable {
    let id = UUID()
    let image: UIImage
}
