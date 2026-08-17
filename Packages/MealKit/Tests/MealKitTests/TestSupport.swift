import Foundation
import FoodFoundation
@testable import MealKit

/// A call-counting stand-in for `FoodFoundation.ProductLookup.fetch`,
/// injected via `MealStore`'s `productResolver` parameter. Lets tests assert
/// exactly when (and how many times) a barcode is resolved — e.g. "browsing
/// an already-added ingredient makes no further network call" — without any
/// live network access, matching this repo's convention of never hitting a
/// real network call from a package's test target (`FoodFoundationTests`
/// tests `ProductLookup`'s mapping logic via decoded fixtures, never live
/// HTTP).
actor StubProductResolver {
    private(set) var callCount = 0
    private(set) var requestedBarcodes: [String] = []
    private var products: [String: Product]

    init(products: [String: Product] = [:]) {
        self.products = products
    }

    /// Registers (or replaces) the product `resolve` returns for `barcode` —
    /// used to simulate a product's data changing between two resolutions,
    /// e.g. to prove template instantiation re-fetches rather than reusing
    /// a stale value.
    func set(_ product: Product, forBarcode barcode: String) {
        products[barcode] = product
    }

    func resolve(_ barcode: String) async throws -> Product {
        callCount += 1
        requestedBarcodes.append(barcode)
        guard let product = products[barcode] else {
            throw ResolutionError.unknownBarcode(barcode)
        }
        return product
    }

    enum ResolutionError: Error, Equatable {
        case unknownBarcode(String)
    }
}

/// Shared fixture builders for `MealKitTests`, mirroring the style of
/// `PantryKitTests`' private `product`/`nutrition`/`unit` helpers.
enum Fixture {
    static func product(
        barcode: String = "0000000001",
        name: String = "Test Bread",
        brand: String? = "Test Brand",
        nutrition: Nutrition? = nutrition()
    ) -> Product {
        Product(
            id: barcode,
            name: name,
            brand: brand,
            imageURL: URL(string: "https://example.com/\(barcode).jpg"),
            nutriScoreGrade: nil,
            categoriesTags: [],
            nutrition: nutrition
        )
    }

    static func nutrition(calories: Double = 250) -> Nutrition {
        Nutrition(energyKcal100g: calories, proteins100g: 5, carbohydrates100g: 30, fat100g: 8, sugars100g: 3, fiber100g: 2, sodium100g: 0.5)
    }

    static func emptyNutrition() -> Nutrition {
        Nutrition(energyKcal100g: 0, proteins100g: 0, carbohydrates100g: 0, fat100g: 0, sugars100g: 0, fiber100g: 0, sodium100g: 0)
    }

    /// A count-tracked unit (e.g. "slices"), 50g each.
    static func countUnit(label: String = "slices", gramsPerUnit: Double? = 50) -> ProductUnit {
        ProductUnit(label: label, quantityPerPackage: 1, gramsPerUnit: gramsPerUnit)
    }

    /// A weight-tracked unit ("g"), always `gramsPerUnit == 1` per
    /// `ProductUnit`'s own convention.
    static func weightUnit() -> ProductUnit {
        ProductUnit(label: "g", quantityPerPackage: 1, gramsPerUnit: 1)
    }
}

/// A day-boundary-safe date builder so aggregation tests aren't sensitive to
/// the machine's local timezone/current time.
func day(_ offsetFromReference: Int, calendar: Calendar = .current) -> Date {
    let reference = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    return calendar.date(byAdding: .day, value: offsetFromReference, to: reference)!
}
