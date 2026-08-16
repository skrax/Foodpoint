import Foundation
import OpenFoodFacts

/// Maps Open Food Facts' wire-format types to the app's own `Product`/
/// `Nutrition` models. This is the only file that should import
/// `OpenFoodFacts` and touch its `FoodProduct`/`Nutriments` types —
/// everywhere else in the app works with `Product`/`Nutrition`.
extension Product {
    init(offProduct: OpenFoodFacts.FoodProduct) {
        self.init(
            id: offProduct.barcode,
            name: offProduct.productName,
            brand: offProduct.brands,
            imageURL: offProduct.imageFrontUrl.flatMap(URL.init(string:)),
            nutriScoreGrade: offProduct.nutriScoreGrade,
            categoriesTags: offProduct.categoriesTags ?? [],
            nutrition: offProduct.nutriments.map(Nutrition.init(offNutriments:))
        )
    }
}

extension Nutrition {
    init(offNutriments: OpenFoodFacts.Nutriments) {
        self.init(
            energyKcal100g: offNutriments.energyKcal100g,
            proteins100g: offNutriments.proteins100g,
            carbohydrates100g: offNutriments.carbohydrates100g,
            fat100g: offNutriments.fat100g,
            sugars100g: offNutriments.sugars100g,
            fiber100g: offNutriments.fiber100g,
            sodium100g: offNutriments.sodium100g
        )
    }
}
