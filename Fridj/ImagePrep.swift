//
//  ImagePrep.swift
//  Fridj
//
//  Created by Gabriel Nejad on 5/28/26.
//
//  ImagePrep.swift
//  Fridj
//
//  The invisible on-device step: take whatever the user picked (often HEIC
//  from an iPhone), downscale it, and hand back a JPEG base64 string ready
//  to upload. The user never knows this happened. Smaller upload = faster
//  scan + lower cost + stays under request size limits.
//

import UIKit

enum ImagePrep {
    /// Downscale to a max long-edge, JPEG-compress, return base64 (no data: prefix).
    static func jpegBase64(from image: UIImage, maxEdge: CGFloat = 1024, quality: CGFloat = 0.7) -> String? {
        let resized = downscale(image, maxEdge: maxEdge)
        guard let data = resized.jpegData(compressionQuality: quality) else { return nil }
        return data.base64EncodedString()
    }

    /// Proportionally shrink so the longest side is at most `maxEdge`.
    static func downscale(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let w = image.size.width
        let h = image.size.height
        let longest = max(w, h)
        guard longest > maxEdge else { return image } // already small enough

        let scale = maxEdge / longest
        let newSize = CGSize(width: w * scale, height: h * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
