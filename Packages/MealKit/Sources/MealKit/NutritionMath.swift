import Foundation
import FoodFoundation

/// Summing/averaging helpers for `Nutrition`, used only by this package's
/// aggregation logic (`MealStore.dayTotal`/`rangeSummary`). Kept `internal`
/// and local to `MealKit` rather than added to `FoodFoundation` itself,
/// since summation is a meals-specific concern (nothing in `PantryKit`
/// combines two `Nutrition` values) — see package-architecture.md §1 on
/// keeping shared additions to `FoodFoundation` limited to genuinely shared
/// vocabulary.
extension Nutrition {
    /// All fields zero — the identity value for `+`.
    static let zero = Nutrition(
        energyKcal100g: 0,
        proteins100g: 0,
        carbohydrates100g: 0,
        fat100g: 0,
        sugars100g: 0,
        fiber100g: 0,
        sodium100g: 0
    )

    /// Field-wise sum, treating a missing field on either side as zero for
    /// the purpose of the total (whether the *ingredient* it came from was
    /// missing entirely is tracked separately by `NutritionCompleteness`,
    /// not by this operator).
    static func + (lhs: Nutrition, rhs: Nutrition) -> Nutrition {
        Nutrition(
            energyKcal100g: (lhs.energyKcal100g ?? 0) + (rhs.energyKcal100g ?? 0),
            proteins100g: (lhs.proteins100g ?? 0) + (rhs.proteins100g ?? 0),
            carbohydrates100g: (lhs.carbohydrates100g ?? 0) + (rhs.carbohydrates100g ?? 0),
            fat100g: (lhs.fat100g ?? 0) + (rhs.fat100g ?? 0),
            sugars100g: (lhs.sugars100g ?? 0) + (rhs.sugars100g ?? 0),
            fiber100g: (lhs.fiber100g ?? 0) + (rhs.fiber100g ?? 0),
            sodium100g: (lhs.sodium100g ?? 0) + (rhs.sodium100g ?? 0)
        )
    }

    /// Field-wise division, used to turn a range total into a per-day
    /// average. `divisor <= 0` returns `.zero` rather than dividing by zero.
    static func / (lhs: Nutrition, divisor: Double) -> Nutrition {
        guard divisor > 0 else { return .zero }
        return Nutrition(
            energyKcal100g: (lhs.energyKcal100g ?? 0) / divisor,
            proteins100g: (lhs.proteins100g ?? 0) / divisor,
            carbohydrates100g: (lhs.carbohydrates100g ?? 0) / divisor,
            fat100g: (lhs.fat100g ?? 0) / divisor,
            sugars100g: (lhs.sugars100g ?? 0) / divisor,
            fiber100g: (lhs.fiber100g ?? 0) / divisor,
            sodium100g: (lhs.sodium100g ?? 0) / divisor
        )
    }
}
