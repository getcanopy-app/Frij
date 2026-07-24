import Foundation

// Vocabulary the speech recognizer is biased toward while listening. Generic
// English dictation is trained on everyday prose, so it reliably mangles food
// words — especially anything not English in origin (goiabada, gochujang,
// halloumi) and homophone-prone staples ("thyme" → "time", "leek" → "leak").
//
// Feeding these as `contextualStrings` tells the recognizer "these words are
// plausible here," which sharply improves hits on exactly the terms a pantry
// app cares about. The user's OWN pantry names go in first (highest signal —
// they're what actually recurs), topped up with this curated list, and capped
// so the bias stays focused rather than diluted.
enum FoodVocabulary {

    /// Cap on how many phrases we hand the recognizer. Past ~100 the bias
    /// spreads too thin to help, so pantry names win the budget first.
    static let seedLimit = 100

    /// Merge the user's pantry (priority) with the curated list, de-duplicated
    /// case-insensitively, and cap it. Pantry terms come first so a full pantry
    /// never gets crowded out by the generic list.
    static func recognitionSeed(pantry: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for name in pantry + curated {
            let key = name.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(name)
            if out.count >= seedLimit { break }
        }
        return out
    }

    /// Commonly-misheard ingredients. Weighted toward non-English-origin foods
    /// and homophone traps rather than words dictation already gets right.
    static let curated: [String] = [
        // Herbs, spices, aromatics
        "cilantro", "coriander", "cumin", "turmeric", "cardamom", "paprika",
        "saffron", "sumac", "za'atar", "fenugreek", "nutmeg", "allspice",
        "thyme", "oregano", "rosemary", "tarragon", "chives", "fennel",
        // Chilis & pastes
        "gochujang", "harissa", "sriracha", "chipotle", "poblano", "jalapeño",
        "tomatillo", "tahini", "miso", "tamari", "kimchi", "gochugaru",
        // Produce that trips dictation
        "arugula", "radicchio", "endive", "escarole", "kale", "chard",
        "bok choy", "daikon", "jicama", "kohlrabi", "leek", "shallot",
        "scallion", "okra", "plantain", "edamame", "artichoke", "aubergine",
        "courgette", "rutabaga", "parsnip",
        // Cheeses & dairy
        "halloumi", "gruyère", "mascarpone", "ricotta", "burrata", "feta",
        "manchego", "gouda", "brie", "mozzarella", "paneer", "labneh",
        // Grains, legumes, pasta
        "quinoa", "farro", "bulgur", "couscous", "orzo", "gnocchi", "polenta",
        "lentils", "chickpeas", "cannellini", "edamame", "freekeh",
        // Proteins & pantry
        "chorizo", "prosciutto", "pancetta", "anchovy", "capers", "kalamata",
        "goiabada", "guava", "tamarind", "gochujang", "furikake", "dashi",
        "mirin", "hoisin", "gochujang", "ghee", "molasses",
        // Fruit & sweet
        "pomegranate", "persimmon", "lychee", "guava", "passionfruit",
        "cardamom", "pistachio", "hazelnut", "mascarpone",
    ]
}
