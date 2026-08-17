import Foundation

/// The app's own product model, decoupled from Open Food Facts' wire
/// format. Nothing outside `ProductMapping.swift` should construct or
/// depend on the OpenFoodFacts package's `FoodProduct`/`Nutriments` types —
/// they get mapped to `Product`/`Nutrition` right after the network call.
public struct Product: Identifiable {
    public let id: String
    public let name: String?
    public let brand: String?
    public let imageURL: URL?
    public let nutriScoreGrade: String?
    public let categoriesTags: [String]
    /// Mutable so `AppState` can keep it in sync with whichever
    /// `NutritionVariant` is currently the barcode's default (Open Food
    /// Facts' figures, or the user's own).
    public var nutrition: Nutrition?

    public init(
        id: String,
        name: String?,
        brand: String?,
        imageURL: URL?,
        nutriScoreGrade: String?,
        categoriesTags: [String],
        nutrition: Nutrition?
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.imageURL = imageURL
        self.nutriScoreGrade = nutriScoreGrade
        self.categoriesTags = categoriesTags
        self.nutrition = nutrition
    }
}

/// Nutrition facts, per 100g of product (or, after `scaled(by:)`, per
/// count-unit — see `ItemDetailView`). `Codable`/`Equatable` so downstream
/// packages (`MealKit`'s `LoggedIngredient.nutritionSnapshot`) can embed and
/// persist it directly — see meals-feature-design.md §12 decision #1
/// ("plain, Codable-friendly value types").
public struct Nutrition: Codable, Equatable {
    public let energyKcal100g: Double?
    public let proteins100g: Double?
    public let carbohydrates100g: Double?
    public let fat100g: Double?
    public let sugars100g: Double?
    public let fiber100g: Double?
    public let sodium100g: Double?

    public init(
        energyKcal100g: Double?,
        proteins100g: Double?,
        carbohydrates100g: Double?,
        fat100g: Double?,
        sugars100g: Double?,
        fiber100g: Double?,
        sodium100g: Double?
    ) {
        self.energyKcal100g = energyKcal100g
        self.proteins100g = proteins100g
        self.carbohydrates100g = carbohydrates100g
        self.fat100g = fat100g
        self.sugars100g = sugars100g
        self.fiber100g = fiber100g
        self.sodium100g = sodium100g
    }

    /// Converts these per-100g figures to per-count-unit figures.
    /// `factor` is `gramsPerUnit / 100` — e.g. a 40g bar gives `factor = 0.4`.
    public func scaled(by factor: Double) -> Nutrition {
        Nutrition(
            energyKcal100g: energyKcal100g.map { $0 * factor },
            proteins100g: proteins100g.map { $0 * factor },
            carbohydrates100g: carbohydrates100g.map { $0 * factor },
            fat100g: fat100g.map { $0 * factor },
            sugars100g: sugars100g.map { $0 * factor },
            fiber100g: fiber100g.map { $0 * factor },
            sodium100g: sodium100g.map { $0 * factor }
        )
    }
}
