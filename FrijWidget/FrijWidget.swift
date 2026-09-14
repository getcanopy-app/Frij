import WidgetKit
import SwiftUI

// "What's for dinner?" — a home/lock screen shortcut straight into a scan.
//
// Deliberately carries NO user data. A widget that showed the streak or pantry
// count would need an App Group, a shared container and matching provisioning
// on both targets — real complexity for a first version whose whole job is to
// be a one-tap way back in. If we later want live data here, that's the moment
// to add the App Group, not before.
//
// Because there's nothing to refresh, the timeline is a single never-reloading
// entry: the system keeps it on screen for free and we never burn a refresh
// budget we don't need.

struct FrijEntry: TimelineEntry {
    let date: Date
    /// Rotates by day so the widget doesn't read as a dead sticker.
    let prompt: String
}

private let prompts = [
    "What's for dinner?",
    "What's in the fridge?",
    "Dinner's already in there.",
    "Something to cook tonight?",
]

struct FrijProvider: TimelineProvider {
    func placeholder(in context: Context) -> FrijEntry {
        FrijEntry(date: Date(), prompt: prompts[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (FrijEntry) -> Void) {
        completion(FrijEntry(date: Date(), prompt: prompts[0]))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FrijEntry>) -> Void) {
        // One entry per day for a week, then ask again. Cheap, and the copy
        // changes often enough to stay alive without any data dependency.
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let entries = (0..<7).compactMap { offset -> FrijEntry? in
            guard let day = cal.date(byAdding: .day, value: offset, to: start) else { return nil }
            return FrijEntry(date: day, prompt: prompts[(cal.component(.dayOfYear, from: day)) % prompts.count])
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

/// Frij's cream + orange, restated here because a widget extension can't see
/// the app target's design system without sharing those files into it. Kept
/// deliberately small — if this grows, share the real tokens instead.
private extension Color {
    static let wCream = Color(red: 0.996, green: 0.980, blue: 0.921)
    static let wOrange = Color(red: 0.933, green: 0.490, blue: 0.302)
    static let wInk = Color(red: 0.176, green: 0.176, blue: 0.176)
}

struct FrijWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FrijEntry

    var body: some View {
        switch family {
        case .accessoryCircular:   circular
        case .accessoryRectangular: rectangular
        case .systemMedium:        medium
        default:                   small
        }
    }

    // Home screen, small: the prompt and an unmistakable scan affordance.
    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            FridgeMark(size: 26)
            Spacer(minLength: 0)
            Text(entry.prompt)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.wInk)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            scanPill
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Color.wCream, for: .widget)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                FridgeMark(size: 26)
                Spacer(minLength: 0)
                Text(entry.prompt)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.wInk)
                    .lineLimit(2)
                Text("Snap your fridge — Frij finds three dinners.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.wInk.opacity(0.55))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            scanPill
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(Color.wCream, for: .widget)
    }

    // Lock screen: monochrome, so only shape reads. No colour, no background.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "viewfinder")
                .font(.system(size: 22, weight: .semibold))
        }
        .containerBackground(.clear, for: .widget)
    }

    private var rectangular: some View {
        HStack(spacing: 6) {
            Image(systemName: "viewfinder").font(.system(size: 14, weight: .bold))
            Text(entry.prompt)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .containerBackground(.clear, for: .widget)
    }

    private var scanPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "viewfinder")
                .font(.system(size: 13, weight: .bold))
            Text("Scan")
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.wOrange, in: Capsule())
    }
}

/// The Frij fridge, drawn rather than bundled — an asset would have to be
/// duplicated into the extension's own catalog.
private struct FridgeMark: View {
    var size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            .fill(Color(red: 0.478, green: 0.729, blue: 0.361))
            .frame(width: size, height: size)
            .overlay(
                VStack(spacing: size * 0.10) {
                    RoundedRectangle(cornerRadius: 1).fill(.white.opacity(0.85))
                        .frame(width: size * 0.10, height: size * 0.16)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Rectangle().fill(.white.opacity(0.5)).frame(height: 1)
                    Spacer(minLength: 0)
                }
                .padding(size * 0.18)
            )
    }
}

// MARK: - Widget

struct FrijWidget: Widget {
    let kind = "FrijScanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FrijProvider()) { entry in
            FrijWidgetView(entry: entry)
                // Opens the app straight into the camera rather than the last
                // tab they were on — the widget's entire promise is one tap.
                .widgetURL(URL(string: "frij://scan"))
        }
        .configurationDisplayName("What's for dinner?")
        .description("One tap to scan your fridge and get three dinners.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct FrijWidgetBundle: WidgetBundle {
    var body: some Widget { FrijWidget() }
}

#Preview(as: .systemSmall) {
    FrijWidget()
} timeline: {
    FrijEntry(date: .now, prompt: "What's for dinner?")
}
