import SwiftUI
import UIKit

/// Every meal the user has actually cooked — their private cookbook.
///
/// A cook is recorded the moment they tap "I cooked this", with or without a
/// photo: the cookbook is a record of cooking, never a photo album you have to
/// feed. A photo just makes an entry nicer, and can be added later.
///
/// Entries live in a JSON file rather than UserDefaults because photos come
/// with them: the images are real files on disk (UserDefaults would balloon
/// and get slow), and the JSON only carries their filenames.
@MainActor
@Observable
final class CookbookStore {
    static let shared = CookbookStore()

    struct Entry: Identifiable, Codable, Hashable {
        let id: UUID
        let recipe: Recipe
        let cookedAt: Date
        /// Filename inside the photos directory. Nil until they snap one.
        var photoFile: String?
        var caption: String?
    }

    private(set) var entries: [Entry] = []          // newest first

    /// How many cooks in a row went by without a photo. After a few, the app
    /// stops leading with the photo button — see `leadsWithPhotoButton`.
    private(set) var consecutiveSkips: Int = 0

    private let skipsKey = "frij.cookbook.skips"
    private let maxEntries = 500
    private let decoded = NSCache<NSString, UIImage>()

    private init() {
        consecutiveSkips = UserDefaults.standard.integer(forKey: skipsKey)
        load()
    }

    // MARK: Cooking

    /// Log a cook. Returns the entry so the caller can offer a photo for it.
    @discardableResult
    func record(_ recipe: Recipe) -> Entry {
        // A cook that came and went without a photo is a skip. Counting it
        // here — when the NEXT cook arrives — means no view has to report
        // "they ignored me", which no screen can reliably know.
        if let previous = entries.first, previous.photoFile == nil {
            consecutiveSkips += 1
        } else if entries.first != nil {
            consecutiveSkips = 0
        }
        UserDefaults.standard.set(consecutiveSkips, forKey: skipsKey)

        let entry = Entry(id: UUID(), recipe: recipe, cookedAt: Date(),
                          photoFile: nil, caption: nil)
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            // Drop the oldest, and their photos with them.
            for old in entries.suffix(from: maxEntries) { deletePhotoFile(old.photoFile) }
            entries = Array(entries.prefix(maxEntries))
        }
        save()
        return entry
    }

    func entry(_ id: UUID) -> Entry? { entries.first { $0.id == id } }

    // MARK: Photos

    /// Attach (or replace) the photo on an entry. Saving a photo is the user
    /// opting in, so it clears the skip count.
    func attachPhoto(_ image: UIImage, caption: String?, to id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        deletePhotoFile(entries[index].photoFile)

        let name = "\(id.uuidString).jpg"
        guard let data = Self.jpeg(image) else { return }
        try? FileManager.default.createDirectory(at: Self.photosDirectory,
                                                 withIntermediateDirectories: true)
        guard (try? data.write(to: Self.photosDirectory.appendingPathComponent(name))) != nil
        else { return }

        entries[index].photoFile = name
        let trimmed = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        entries[index].caption = (trimmed?.isEmpty == false) ? trimmed : nil
        decoded.removeObject(forKey: name as NSString)

        consecutiveSkips = 0
        UserDefaults.standard.set(0, forKey: skipsKey)
        save()
    }

    func photo(for entry: Entry) -> UIImage? {
        guard let file = entry.photoFile else { return nil }
        if let hit = decoded.object(forKey: file as NSString) { return hit }
        let url = Self.photosDirectory.appendingPathComponent(file)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        decoded.setObject(image, forKey: file as NSString)
        return image
    }

    func delete(_ entry: Entry) {
        deletePhotoFile(entry.photoFile)
        entries.removeAll { $0.id == entry.id }
        save()
    }

    /// True while the full "Snap your plate" button is the right thing to show.
    /// After a few silent skips it stays available, just smaller and quieter —
    /// the point is to offer it, not to keep asking.
    var leadsWithPhotoButton: Bool { consecutiveSkips < 3 }

    // MARK: Stats

    var mealsCooked: Int { entries.count }

    /// Entries grouped for the gallery: this week, then by month.
    var sections: [(title: String, entries: [Entry])] {
        let cal = Calendar.current
        let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date()))
        var thisWeek: [Entry] = []
        var older: [Entry] = []
        for entry in entries {
            if let weekStart, entry.cookedAt >= weekStart { thisWeek.append(entry) }
            else { older.append(entry) }
        }
        var out: [(String, [Entry])] = []
        if !thisWeek.isEmpty { out.append(("THIS WEEK", thisWeek)) }
        for entry in older {
            let title = Self.monthFormatter.string(from: entry.cookedAt).uppercased()
            if out.last?.0 == title { out[out.count - 1].1.append(entry) }
            else { out.append((title, [entry])) }
        }
        return out
    }

    /// "Today", "Yesterday", "Wed", then a date.
    static func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if let days = cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                         to: cal.startOfDay(for: Date())).day, days < 7 {
            return weekdayFormatter.string(from: date)
        }
        return shortDateFormatter.string(from: date)
    }

    // MARK: Storage

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM"; return f
    }()
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()

    private static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    private static var storeURL: URL { documents.appendingPathComponent("cookbook.json") }
    private static var photosDirectory: URL { documents.appendingPathComponent("CookbookPhotos", isDirectory: true) }

    /// Long edge capped so a 12MP photo doesn't sit on disk at 5 MB.
    private static func jpeg(_ image: UIImage, maxEdge: CGFloat = 1600) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxEdge else { return image.jpegData(compressionQuality: 0.85) }
        let scale = maxEdge / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.85)
    }

    private func deletePhotoFile(_ name: String?) {
        guard let name else { return }
        decoded.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: Self.photosDirectory.appendingPathComponent(name))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.storeURL),
              let saved = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = saved
    }
}
