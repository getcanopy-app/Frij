//
//  FlowLayout.swift
//  Fridj
//

import SwiftUI

// Left-to-right wrapping layout so chips hug their content and sit next to each
// other, wrapping to a new line only when they run out of width. Replaces a
// LazyVGrid, which spread a small number of chips across the full width (2 chips
// ended up at opposite edges with a big gap).
//
// Shared by the scan-result chips in ExpandableTabBar and the pantry chips in
// PantryView — it lived in ExpandableTabBar.swift as `fileprivate` until the
// pantry needed the same behaviour.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                widestRow = max(widestRow, x - spacing)
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        widestRow = max(widestRow, x - spacing)
        totalHeight += rowHeight

        // Report the full proposed width rather than the widest row. Reporting a
        // narrower width gets us placed into narrower bounds than we measured
        // against, so placeSubviews wraps onto more lines than `totalHeight`
        // accounts for — and whatever follows overlaps the last row.
        return CGSize(width: maxWidth.isFinite ? maxWidth : widestRow,
                      height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
