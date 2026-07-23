//
//  PantryCategory.swift
//  Fridj
//
//  Groups pantry items into kitchen sections for display.
//
//  Deliberately local and offline: classification is cosmetic (it only decides
//  which header an item sits under), so it isn't worth a network round-trip or
//  the latency/cost of asking the backend. Anything unrecognized lands in
//  `.other`, which is a fine outcome rather than a failure.
//
//  Matching is longest-keyword-wins, which is what resolves the overlaps:
//  "black pepper" beats "pepper" (staples, not produce), "eggplant" beats "egg"
//  (produce, not protein), "peanut butter" beats "butter" (staples, not dairy).
//  When adding keywords, prefer the most specific phrase.
//

import Foundation

enum PantryCategory: String, CaseIterable, Hashable {
    case produce, protein, dairy, staples, other

    /// Display order follows `allCases`.
    var title: String {
        switch self {
        case .produce: return "Produce"
        case .protein: return "Protein"
        case .dairy:   return "Dairy"
        case .staples: return "Staples"
        case .other:   return "Other"
        }
    }

    static func classify(_ rawName: String) -> PantryCategory {
        let name = rawName.lowercased().trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return .other }
        let forms = singularForms(of: name)

        var best: (category: PantryCategory, length: Int)?
        for category in PantryCategory.allCases where category != .other {
            for keyword in category.keywords
            where forms.contains(where: { $0.contains(keyword) }) {
                if best == nil || keyword.count > best!.length {
                    best = (category, keyword.count)
                }
            }
        }
        return best?.category ?? .other
    }

    /// A plain `contains` match misses plurals: "strawberries" does not contain
    /// "strawberry", so berries and tomatoes fell through to `.other`. Matching
    /// against de-pluralized forms too lets the keyword lists stay singular.
    private static func singularForms(of name: String) -> [String] {
        var forms = [name]
        if name.hasSuffix("ies") {
            forms.append(String(name.dropLast(3)) + "y")   // berries -> berry
        }
        if name.hasSuffix("es") {
            forms.append(String(name.dropLast(2)))          // tomatoes -> tomato
        }
        if name.hasSuffix("s") {
            forms.append(String(name.dropLast()))           // grapes -> grape
        }
        return forms
    }

    private var keywords: [String] {
        switch self {
        case .produce:
            return ["apple", "apricot", "artichoke", "arugula", "asparagus", "avocado",
                    "banana", "basil", "beet", "bell pepper", "berry", "blackberry",
                    "blueberry", "bok choy", "broccoli", "brussels", "cabbage",
                    "cantaloupe", "carrot", "cauliflower", "celery", "chard", "cherry",
                    "chili", "cilantro", "clementine", "corn", "cucumber", "dill",
                    "eggplant", "fennel", "garlic", "ginger", "grape", "grapefruit",
                    "green bean", "green onion", "greens", "herbs", "jalapeno", "kale",
                    "kiwi", "leek", "lemon", "lettuce", "lime", "mango", "melon", "mint",
                    "mushroom", "nectarine", "okra", "onion", "orange", "papaya",
                    "parsley", "parsnip", "peach", "pear", "peas", "pepper", "pineapple",
                    "plum", "pomegranate", "potato", "pumpkin", "radish", "raspberry",
                    "romaine", "rosemary", "sage", "salad", "scallion", "shallot",
                    "spinach", "sprouts", "squash", "strawberry", "sweet potato",
                    "thyme", "tomato", "turnip", "watercress", "watermelon", "zucchini"]

        case .protein:
            return ["anchovy", "bacon", "beef", "black bean", "brisket", "chicken",
                    "chickpea", "chorizo", "clam", "cod", "crab", "duck", "egg", "fish",
                    "ground beef", "ground turkey", "halibut", "ham", "hot dog",
                    "kidney bean", "lamb", "lentil", "lobster", "meatball", "mussel",
                    "pancetta", "pepperoni", "pork", "prawn", "prosciutto", "salami",
                    "salmon", "sardine", "sausage", "scallop", "shrimp", "steak",
                    "tempeh", "tilapia", "tofu", "tuna", "turkey", "veal", "venison"]

        case .dairy:
            return ["brie", "butter", "buttermilk", "cheddar", "cheese", "cottage cheese",
                    "cream", "cream cheese", "feta", "ghee", "goat cheese", "gouda",
                    "greek yogurt", "half and half", "heavy cream", "mascarpone", "milk",
                    "mozzarella", "parmesan", "provolone", "ricotta", "sour cream",
                    "swiss", "whipped cream", "yoghurt", "yogurt"]

        case .staples:
            return ["all-purpose flour", "almond", "baking powder", "baking soda",
                    "balsamic", "barley", "basmati", "black pepper", "bread",
                    "breadcrumbs", "broth", "brown sugar", "cashew", "cereal", "chia",
                    "chili flakes", "cinnamon", "cocoa", "coconut milk", "coffee",
                    "chocolate", "cornstarch", "couscous", "cumin", "curry powder",
                    "flour", "honey", "jam", "marshmallow", "nutella",
                    "hot sauce", "ketchup", "maple syrup", "mayo", "mayonnaise",
                    "mustard", "noodle", "nutmeg", "oat", "oil", "olive oil", "oregano",
                    "panko", "paprika", "pasta", "peanut butter", "pecan", "penne",
                    "peppercorn", "pesto", "pickle", "quinoa", "ramen", "rice", "salt",
                    "sesame oil", "soy sauce", "spaghetti", "sriracha", "stock", "sugar",
                    "syrup", "tabasco", "tahini", "tomato paste", "tomato sauce",
                    "tortilla", "turmeric", "vanilla", "vinegar", "walnut",
                    "white pepper", "worcestershire", "yeast"]

        case .other:
            return []
        }
    }
}
