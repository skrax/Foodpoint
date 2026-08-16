import Foundation
import Testing
import OpenFoodFactsKit
@testable import FoodFoundation

@Suite("Product mapping from Open Food Facts")
struct ProductMappingTests {
    // `OpenFoodFactsKit.FoodProduct` has no public memberwise init (only the
    // synthesized `Decodable.init(from:)`), so fixtures are built by
    // decoding realistic JSON - this also exercises the real CodingKeys.
    private func decodeOFFProduct(_ json: String) throws -> OpenFoodFactsKit.FoodProduct {
        try JSONDecoder().decode(OpenFoodFactsKit.FoodProduct.self, from: Data(json.utf8))
    }

    @Test("full product maps every field, including nutrition")
    func fullProductMapsEveryField() throws {
        let offProduct = try decodeOFFProduct("""
        {
            "code": "0000000001",
            "product_name": "Test Bar",
            "brands": "Test Brand",
            "image_front_url": "https://example.com/image.jpg",
            "nutriscore_grade": "b",
            "categories_tags": ["en:snacks", "en:cereal-bars"],
            "nutriments": {
                "energy-kcal_100g": 250,
                "proteins_100g": 5.2,
                "carbohydrates_100g": 30,
                "fat_100g": 8,
                "sugars_100g": 3,
                "fiber_100g": 2,
                "sodium_100g": 0.5
            }
        }
        """)

        let product = Product(offProduct: offProduct)

        #expect(product.id == "0000000001")
        #expect(product.name == "Test Bar")
        #expect(product.brand == "Test Brand")
        #expect(product.imageURL == URL(string: "https://example.com/image.jpg"))
        #expect(product.nutriScoreGrade == "b")
        #expect(product.categoriesTags == ["en:snacks", "en:cereal-bars"])
        #expect(product.nutrition?.energyKcal100g == 250)
        #expect(product.nutrition?.proteins100g == 5.2)
        #expect(product.nutrition?.sodium100g == 0.5)
    }

    @Test("missing categories_tags maps to an empty array, not nil")
    func missingCategoriesTagsMapsToEmptyArray() throws {
        let offProduct = try decodeOFFProduct("""
        { "code": "0000000002" }
        """)
        let product = Product(offProduct: offProduct)
        #expect(product.categoriesTags.isEmpty)
    }

    @Test("missing nutriments maps to nil nutrition")
    func missingNutrimentsMapsToNilNutrition() throws {
        let offProduct = try decodeOFFProduct("""
        { "code": "0000000003" }
        """)
        let product = Product(offProduct: offProduct)
        #expect(product.nutrition == nil)
    }

    @Test("a nutriments object with every field blank maps to a non-nil but effectively-empty Nutrition")
    func blankNutrimentsMapsToEffectivelyEmptyNutrition() throws {
        // The real-world case that motivated isEffectivelyEmpty: OFF
        // sometimes includes the nutriments key with no fields filled in,
        // rather than omitting it.
        let offProduct = try decodeOFFProduct("""
        { "code": "0000000004", "nutriments": {} }
        """)
        let product = Product(offProduct: offProduct)
        #expect(product.nutrition != nil)
        #expect(product.nutrition?.isEffectivelyEmpty == true)
    }

    @Test("an unparseable image URL maps to nil rather than throwing")
    func unparseableImageURLMapsToNil() throws {
        let offProduct = try decodeOFFProduct("""
        { "code": "0000000005", "image_front_url": "" }
        """)
        let product = Product(offProduct: offProduct)
        #expect(product.imageURL == nil)
    }
}
