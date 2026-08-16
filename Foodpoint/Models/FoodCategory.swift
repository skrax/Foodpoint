import Foundation

/// A coarse grocery category used to pick an icon for a product, derived
/// best-effort from Open Food Facts' category tags (see `FoodProduct.category`).
enum FoodCategory: String, CaseIterable {
    case fruitsAndVegetables = "Fruits & Vegetables"
    case dairyAndEggs = "Dairy & Eggs"
    case meatAndFish = "Meat & Fish"
    case bakeryAndGrains = "Bakery & Grains"
    case beverages = "Beverages"
    case snacksAndSweets = "Snacks & Sweets"
    case frozen = "Frozen"
    case other = "Other"

    /// SF Symbol shown next to products of this category.
    var icon: String {
        switch self {
        case .fruitsAndVegetables: "carrot.fill"
        case .dairyAndEggs: "cup.and.saucer.fill"
        case .meatAndFish: "fish.fill"
        case .bakeryAndGrains: "birthday.cake.fill"
        case .beverages: "wineglass.fill"
        case .snacksAndSweets: "popcorn.fill"
        case .frozen: "snowflake"
        case .other: "fork.knife"
        }
    }
}

extension FoodProduct {
    /// Best-effort guess from Open Food Facts' free-form category tags.
    ///
    /// OFF's `categories_tags` vocabulary is huge and inconsistent, so this
    /// does simple keyword matching (checked in order, most specific first)
    /// rather than trying to map the full taxonomy. Falls back to `.other`
    /// when there's no useful data or no keyword matches.
    var category: FoodCategory {
        guard let tags = categoriesTags, !tags.isEmpty else { return .other }
        let joined = tags.joined(separator: " ").lowercased()

        if joined.contains("frozen") {
            return .frozen
        }
        if joined.contains("beverage") || joined.contains("drink") || joined.contains("juice") || joined.contains("soda") || joined.contains("water") {
            return .beverages
        }
        if joined.contains("dair") || joined.contains("milk") || joined.contains("cheese") || joined.contains("yogurt") || joined.contains("egg") {
            return .dairyAndEggs
        }
        if joined.contains("meat") || joined.contains("fish") || joined.contains("seafood") || joined.contains("poultry") || joined.contains("sausage") {
            return .meatAndFish
        }
        if joined.contains("bread") || joined.contains("bakery") || joined.contains("cereal") || joined.contains("pasta") || joined.contains("rice") || joined.contains("grain") {
            return .bakeryAndGrains
        }
        if joined.contains("snack") || joined.contains("sweet") || joined.contains("chocolate") || joined.contains("candy") || joined.contains("biscuit") || joined.contains("cake") || joined.contains("dessert") {
            return .snacksAndSweets
        }
        if joined.contains("vegetable") || joined.contains("fruit") || joined.contains("plant-based") {
            return .fruitsAndVegetables
        }

        return .other
    }
}
