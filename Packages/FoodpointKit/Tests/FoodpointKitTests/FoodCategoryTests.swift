import Testing
@testable import FoodpointKit

@Suite("FoodCategory")
struct FoodCategoryTests {
    private func product(categoriesTags: [String]) -> Product {
        Product(id: "0", name: nil, brand: nil, imageURL: nil, nutriScoreGrade: nil, categoriesTags: categoriesTags, nutrition: nil)
    }

    @Test("empty tags fall back to other")
    func emptyTagsFallBackToOther() {
        #expect(product(categoriesTags: []).category == .other)
    }

    @Test("unmatched tags fall back to other")
    func unmatchedTagsFallBackToOther() {
        #expect(product(categoriesTags: ["en:something-unusual"]).category == .other)
    }

    @Test("frozen is checked before other keywords")
    func frozenTakesPriority() {
        // Contains both "frozen" and "meat" - frozen should win since it's
        // checked first in the keyword ladder.
        #expect(product(categoriesTags: ["en:frozen-meat-products"]).category == .frozen)
    }

    @Test("dairy keywords map to dairy and eggs")
    func dairyKeywords() {
        #expect(product(categoriesTags: ["en:dairies", "en:cheeses"]).category == .dairyAndEggs)
    }

    @Test("meat and fish keywords map to meat and fish")
    func meatAndFishKeywords() {
        #expect(product(categoriesTags: ["en:meats", "en:poultry"]).category == .meatAndFish)
        #expect(product(categoriesTags: ["en:fresh-fish"]).category == .meatAndFish)
    }

    @Test("bread keywords map to bakery and grains")
    func bakeryKeywords() {
        #expect(product(categoriesTags: ["en:breads"]).category == .bakeryAndGrains)
    }

    @Test("sweet/chocolate keywords map to snacks and sweets")
    func snackKeywords() {
        #expect(product(categoriesTags: ["en:sweet-snacks", "en:chocolates"]).category == .snacksAndSweets)
    }

    @Test("beverage keywords map to beverages")
    func beverageKeywords() {
        #expect(product(categoriesTags: ["en:beverages", "en:sodas"]).category == .beverages)
    }

    @Test("produce keywords map to fruits and vegetables")
    func produceKeywords() {
        #expect(product(categoriesTags: ["en:fresh-vegetables"]).category == .fruitsAndVegetables)
        #expect(product(categoriesTags: ["en:plant-based-foods"]).category == .fruitsAndVegetables)
    }
}
