import Foundation

/// Where a `NutritionVariant`'s numbers came from — shown as a badge so the
/// user can always tell configured data apart from Open Food Facts' own.
enum NutritionSource: String {
    case openFoodFacts = "Open Food Facts"
    case custom = "Custom"
}

/// A named nutrition data set for a barcode — either fetched from Open Food
/// Facts or entered manually by the user. Mirrors `ProductUnit`: a barcode
/// can have several (one default plus alternates), stored in
/// `AppState.nutritionConfigs`/`nutritionVariants`, with a stable `id` for
/// editing/selection independent of a (possibly-edited) `name`.
struct NutritionVariant: Identifiable {
    let id: UUID
    var name: String
    var nutrition: Nutrition
    let source: NutritionSource

    init(id: UUID = UUID(), name: String, nutrition: Nutrition, source: NutritionSource) {
        self.id = id
        self.name = name
        self.nutrition = nutrition
        self.source = source
    }
}

extension Nutrition {
    /// True when every field is nil or zero. Some Open Food Facts entries
    /// carry a `nutriments` object with no fields actually filled in rather
    /// than omitting it, which otherwise renders as "0 kcal, 0.0g protein…"
    /// indistinguishable from genuine zero values.
    var isEffectivelyEmpty: Bool {
        [energyKcal100g, proteins100g, carbohydrates100g, fat100g, sugars100g, fiber100g, sodium100g]
            .allSatisfy { ($0 ?? 0) == 0 }
    }

    /// Tolerant of tiny floating-point drift — used to detect whether Open
    /// Food Facts' data has meaningfully changed since it was last seen,
    /// so the user isn't re-asked about the same values every scan.
    func isApproximatelyEqual(to other: Nutrition) -> Bool {
        func close(_ a: Double?, _ b: Double?) -> Bool {
            switch (a, b) {
            case (nil, nil): return true
            case let (x?, y?): return abs(x - y) < 0.01
            default: return false
            }
        }
        return close(energyKcal100g, other.energyKcal100g)
            && close(proteins100g, other.proteins100g)
            && close(carbohydrates100g, other.carbohydrates100g)
            && close(fat100g, other.fat100g)
            && close(sugars100g, other.sugars100g)
            && close(fiber100g, other.fiber100g)
            && close(sodium100g, other.sodium100g)
    }
}
