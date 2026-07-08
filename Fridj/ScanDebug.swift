//
//  ScanDebug.swift
//  Fridj
//
//  TEMPORARY scan-quality diagnostics. Prints (a) the actual image bytes we
//  upload and (b) everything the backend returned — all confidences, BEFORE
//  the `.high`-only filter drops medium/low. Lets us tell apart the three
//  levers: weak input resolution, over-aggressive confidence filtering, or a
//  weak backend prompt. DEBUG-only; delete this file once scan quality is
//  dialed in. See memory: frij-scan-quality-next.
//

#if DEBUG
import UIKit

enum ScanDebug {
    /// What actually goes over the wire — true uploaded pixels + JPEG size.
    /// Called from ImagePrep.jpegBase64 with the already-downscaled image.
    static func dumpUpload(image: UIImage, jpegBytes: Int, quality: CGFloat) {
        let px = CGSize(width: image.size.width * image.scale,
                        height: image.size.height * image.scale)
        let kb = Double(jpegBytes) / 1024.0
        print("┌─── FRIJ UPLOAD ───────────────────────────")
        print("│ uploaded: \(Int(px.width))×\(Int(px.height)) px  ·  q\(quality)  ·  \(String(format: "%.0f", kb)) KB")
        print("└───────────────────────────────────────────")
    }

    /// What the backend returned — every item + confidence, before filtering.
    /// Called from runScan right after FrijAPI.scan returns.
    static func dumpScan(_ items: [DetectedItem]) {
        let high   = items.filter { $0.confidence == .high }.count
        let medium = items.filter { $0.confidence == .medium }.count
        let low    = items.filter { $0.confidence == .low }.count

        print("┌─── FRIJ SCAN RESULT ──────────────────────")
        print("│ returned \(items.count)  ·  high:\(high)  medium:\(medium)  low:\(low)")
        print("│ MERGED into pantry: \(high)   ·   DROPPED (med+low): \(medium + low)")
        print("│")
        for item in items.sorted(by: { $0.confidence.debugRank < $1.confidence.debugRank }) {
            let mark = item.confidence == .high ? "✓ keep" : "· drop"
            let conf = item.confidence.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)
            let box = item.box.map {
                String(format: "  box[%.2f,%.2f %.2fx%.2f]", $0.x, $0.y, $0.w, $0.h)
            } ?? ""
            print("│ \(mark)  [\(conf)] \(item.item)\(box)")
        }
        print("└───────────────────────────────────────────")
    }
}

private extension Confidence {
    var debugRank: Int {
        switch self {
        case .high:   return 0
        case .medium: return 1
        case .low:    return 2
        }
    }
}
#endif
