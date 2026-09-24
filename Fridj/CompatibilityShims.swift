import SwiftUI

// iOS 26 brought Liquid Glass (`glassEffect`) and the scroll-edge effect.
// Frij supports iOS 17 and up, so every one of those calls goes through a
// shim: the newer look on 26, a plain material of the SAME shape below it.
// Older iOS sees a flat frosted pill instead of refracting glass — which is
// simply how that OS looks — and nothing else about the app changes.
extension View {
    @ViewBuilder
    func frijGlass(cornerRadius: CGFloat, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                tint.map { .regular.tint($0) } ?? .regular,
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            self.background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint ?? .clear)
                    )
            )
        }
    }

    /// Hides the iOS 26 scroll-edge effect; a no-op on older systems, which
    /// never draw it in the first place.
    @ViewBuilder
    func frijHideScrollEdge(_ hidden: Bool = true, for edge: Edge.Set = .top) -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectHidden(hidden, for: edge)
        } else {
            self
        }
    }
}
