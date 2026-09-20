import SwiftUI
import UIKit

// The "oh, that looks nice" moment: the photo they just took, framed like a
// Frij recipe card. This is the whole reason anyone bothers taking the photo,
// so it gets the same rounded-card language as the recipe sheet — a keepsake,
// not a sticker with a watermark.

struct KeepsakeView: View {
    let entry: CookbookStore.Entry
    let image: UIImage
    /// Called once the photo is on the entry, so the caller can close out.
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var caption: String = ""
    @State private var shareDoc: ShareDoc?
    @State private var isRendering = false
    @FocusState private var captionFocused: Bool

    private var cookbook: CookbookStore { CookbookStore.shared }

    var body: some View {
        // A NavigationStack rather than a bare VStack: presented as a
        // fullScreenCover from inside a sheet, plain content gets no top safe
        // area and the title lands under the Dynamic Island.
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.fridjText.opacity(0.55))
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Text("Your cook")
                            .font(FridjFont.size(18, weight: .bold))
                            .foregroundColor(.fridjText)
                    }
                }
                .toolbarBackground(Color.fridjBg, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    KeepsakeCard(recipe: entry.recipe, image: image, cookedAt: entry.cookedAt)
                        .padding(.horizontal, 20)

                    captionField
                        .padding(.horizontal, 20)
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }

            actions
        }
        .background(Color.fridjBg.ignoresSafeArea())
        .sheet(item: $shareDoc) { doc in
            ShareSheet(items: doc.items)
                .presentationDetents([.medium, .large])
        }
        .onTapGesture { captionFocused = false }
    }

    // Never required — an empty caption is a perfectly good caption.
    private var captionField: some View {
        TextField("how'd it turn out?", text: $caption, axis: .vertical)
            .font(FridjFont.size(16))
            .foregroundColor(.fridjText)
            .focused($captionFocused)
            .lineLimit(1...3)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.fridjText.opacity(0.08), lineWidth: 1)
            )
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                save()
                onSaved()
                dismiss()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 17, weight: .bold))
                    Text("Save to my cookbook")
                        .font(FridjFont.size(17, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color.fridjSage,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                share()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Share")
                        .font(FridjFont.size(17, weight: .bold))
                }
                .foregroundColor(.fridjText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.fridjText.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isRendering)
            .opacity(isRendering ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    private func save() {
        cookbook.attachPhoto(image, caption: caption, to: entry.id)
    }

    // Sharing saves too. Someone who shares their cook and then closes this
    // screen plainly meant to keep it — losing the photo would be a bug to
    // them, not a respected choice.
    private func share() {
        save()
        isRendering = true
        Task {
            let card = await KeepsakeCard.renderImage(
                recipe: entry.recipe, image: image, cookedAt: entry.cookedAt)
            isRendering = false
            guard let card else { return }
            shareDoc = ShareDoc.meal(image: card,
                                     link: RecipeShareLink.url(for: entry.recipe),
                                     name: entry.recipe.name)
        }
    }
}


/// A photo that fills a box without deciding how big the box is.
///
/// `Image.scaledToFill().frame(height:)` keeps the IMAGE's width for layout —
/// clipping hides the overflow but the card still measures ~4000pt wide, which
/// shoves headers and padding off screen. Letting a Color.clear own the layout
/// and painting the photo in an overlay is what actually contains it.
struct FilledPhoto<Content: View>: View {
    var height: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay { content().scaledToFill() }
            .clipped()
            .contentShape(Rectangle())
    }
}

// MARK: - The card itself

/// Photo + dish + time + a quiet Frij mark. Used on screen AND rendered to a
/// single image for the share sheet, so what they share is what they saw.
struct KeepsakeCard: View {
    let recipe: Recipe
    let image: UIImage
    let cookedAt: Date
    /// Fixed width when rendering for export; nil means "fill the screen".
    var exportWidth: CGFloat? = nil

    private var isExport: Bool { exportWidth != nil }

    var body: some View {
        VStack(spacing: 0) {
            FilledPhoto(height: isExport ? 430 : 330) {
                Image(uiImage: image).resizable()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(recipe.name)
                    .font(FridjFont.size(isExport ? 26 : 24, weight: .bold))
                    .foregroundColor(.fridjText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 8) {
                    Text("\(recipe.cookTime) · \(CookbookStore.shortDateFormatter.string(from: cookedAt))")
                        .font(FridjFont.size(16, weight: .semibold))
                        .foregroundColor(.fridjText.opacity(0.45))
                    Spacer(minLength: 10)
                    madeWithFrij
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white)
        }
        .frame(width: exportWidth)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(isExport ? 0 : 0.10), radius: 18, x: 0, y: 8)
    }

    // Corner branding, deliberately small: the dish is the hero.
    private var madeWithFrij: some View {
        HStack(spacing: 7) {
            Image("FridjLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text("made with Frij")
                .font(FridjFont.size(14, weight: .bold))
                .foregroundColor(.fridjGreen)
        }
    }

    @MainActor
    static func renderImage(recipe: Recipe, image: UIImage, cookedAt: Date) async -> UIImage? {
        let renderer = ImageRenderer(
            content: KeepsakeCard(recipe: recipe, image: image, cookedAt: cookedAt,
                                  exportWidth: 430)
                .background(Color.fridjBg)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

// MARK: - Taking the photo

/// The camera, for "shoot it right now". Photo-library picks go through
/// SwiftUI's own PhotosPicker at the call site.
struct PlateCameraPicker: UIViewControllerRepresentable {
    var onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: PlateCameraPicker
        init(_ parent: PlateCameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPicked(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
