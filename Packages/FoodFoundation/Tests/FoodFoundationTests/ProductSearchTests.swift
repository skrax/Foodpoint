import Foundation
import Testing
import OpenFoodFactsKit
@testable import FoodFoundation

@Suite("Product search mapping")
struct ProductSearchTests {
    // Fixtures shaped like real search-a-licious responses (confirmed
    // against the live API while implementing this) - notably `brands` is
    // an array here, unlike `FoodProduct`'s comma-separated string.
    private func decodeSearchedProduct(_ json: String) throws -> OpenFoodFactsKit.SearchedProduct {
        try JSONDecoder().decode(OpenFoodFactsKit.SearchedProduct.self, from: Data(json.utf8))
    }

    @Test("a searched product maps every field, joining the brands array")
    func searchedProductMapsEveryField() throws {
        let searched = try decodeSearchedProduct("""
        {
            "code": "0000000010",
            "product_name": "Fresh Banana",
            "brands": ["Acme Farms", "Fresh Co"],
            "image_front_url": "https://example.com/banana.jpg",
            "nutriscore_grade": "a",
            "categories_tags": ["en:fruits"],
            "nutriments": {
                "energy-kcal_100g": 89,
                "proteins_100g": 1.1,
                "sugars_100g": 12
            }
        }
        """)

        let product = Product(searchedProduct: searched)

        #expect(product.id == "0000000010")
        #expect(product.name == "Fresh Banana")
        #expect(product.brand == "Acme Farms, Fresh Co")
        #expect(product.imageURL == URL(string: "https://example.com/banana.jpg"))
        #expect(product.nutriScoreGrade == "a")
        #expect(product.categoriesTags == ["en:fruits"])
        #expect(product.nutrition?.energyKcal100g == 89)
    }

    @Test("missing brands maps to a nil brand, not an empty string")
    func missingBrandsMapsToNilBrand() throws {
        let searched = try decodeSearchedProduct("""
        { "code": "0000000011" }
        """)
        let product = Product(searchedProduct: searched)
        #expect(product.brand == nil)
    }

    @Test("multiple search results each map independently")
    func multipleResultsMapIndependently() throws {
        let json = """
        [
            { "code": "0000000012", "product_name": "Banana", "brands": ["Generic"] },
            { "code": "0000000013", "product_name": "Banana Chips", "brands": ["SnackCo"] }
        ]
        """
        let searched = try JSONDecoder().decode([OpenFoodFactsKit.SearchedProduct].self, from: Data(json.utf8))
        let products = searched.map(Product.init(searchedProduct:))

        #expect(products.count == 2)
        #expect(products[0].name == "Banana")
        #expect(products[1].name == "Banana Chips")
    }

    @Test("an empty search result list decodes to an empty array, not an error")
    func emptyResultsDecodeToEmptyArray() throws {
        let searched = try JSONDecoder().decode([OpenFoodFactsKit.SearchedProduct].self, from: Data("[]".utf8))
        #expect(searched.isEmpty)
    }
}
