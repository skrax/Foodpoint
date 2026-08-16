import Foundation

/// The app's own product model, decoupled from Open Food Facts' wire
/// format. Nothing outside `ProductMapping.swift` should construct or
/// depend on the OpenFoodFacts package's `FoodProduct`/`Nutriments` types —
/// they get mapped to `Product`/`Nutrition` right after the network call.
struct Product: Identifiable {
    let id: String
    let name: String?
    let brand: String?
    let imageURL: URL?
    let nutriScoreGrade: String?
    let categoriesTags: [String]
    let nutrition: Nutrition?
}

/// Nutrition facts, per 100g of product (or, after `scaled(by:)`, per
/// count-unit — see `ItemDetailView`).
struct Nutrition {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let sodium100g: Double?

    /// Converts these per-100g figures to per-count-unit figures.
    /// `factor` is `gramsPerUnit / 100` — e.g. a 40g bar gives `factor = 0.4`.
    func scaled(by factor: Double) -> Nutrition {
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
