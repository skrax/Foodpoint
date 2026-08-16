import Foundation
import OpenFoodFactsKit

/// Maps Open Food Facts' wire-format types to the app's own `Product`/
/// `Nutrition` models. This is the only file in the whole dependency graph
/// that should import `OpenFoodFactsKit` and touch its `FoodProduct`/
/// `Nutriments` types — everywhere else (including `PantryKit`, `MealKit`,
/// and the app target) works with `Product`/`Nutrition`.
extension Product {
    public init(offProduct: OpenFoodFactsKit.FoodProduct) {
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

    /// Maps a search-a-licious result (`SearchedProduct`) rather than a
    /// by-barcode `FoodProduct`. The only real difference is `brands`,
    /// which search returns as an array — joined into the same
    /// comma-separated shape `FoodProduct.brands` already uses, so the rest
    /// of the app never has to know which acquisition path a `Product` came
    /// from.
    public init(searchedProduct: OpenFoodFactsKit.SearchedProduct) {
        self.init(
            id: searchedProduct.barcode,
            name: searchedProduct.productName,
            brand: searchedProduct.brands?.joined(separator: ", "),
            imageURL: searchedProduct.imageFrontUrl.flatMap(URL.init(string:)),
            nutriScoreGrade: searchedProduct.nutriScoreGrade,
            categoriesTags: searchedProduct.categoriesTags ?? [],
            nutrition: searchedProduct.nutriments.map(Nutrition.init(offNutriments:))
        )
    }
}

extension Nutrition {
    public init(offNutriments: OpenFoodFactsKit.Nutriments) {
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

/// Resolves a product from Open Food Facts, mapped to the app's own domain
/// model. Stateless and independent of any particular package's state —
/// `PantryKit` and `MealKit` each call this directly rather than sharing a
/// cache or going through one another (see package-architecture.md §3.2).
public enum ProductLookup {
    public static func fetch(barcode: String) async throws -> Product {
        let offProduct = try await OpenFoodFactsService.shared.fetchProduct(barcode: barcode)
        return Product(offProduct: offProduct)
    }

    /// Finds candidates by name when there's no barcode to scan — produce,
    /// bulk goods, and other unlabeled groceries. An empty result is valid;
    /// it just means nothing matched.
    public static func search(query: String) async throws -> [Product] {
        let results = try await OpenFoodFactsService.shared.searchProducts(query: query)
        return results.map(Product.init(searchedProduct:))
    }
}
