import Foundation
import Testing
import FoodFoundation
@testable import MealKit

/// Covers `MealStore.provenanceMix(for:)` and `makeIngredient`'s
/// `nutritionSource` threading (MK-6, meals-feature-design.md §8.3) — the
/// Open Food Facts vs. Custom mix a meal detail view shows.
@Suite("Nutrition-source provenance mix")
struct ProvenanceMixTests {
    private func ingredient(barcode: String = "0001", source: NutritionSource?, hasNutrition: Bool = true) -> LoggedIngredient {
        LoggedIngredient(
            barcode: barcode,
            productName: "Test",
            productBrand: nil,
            imageURL: nil,
            amount: 1,
            unitLabel: "g",
            gramsResolved: 100,
            nutritionSnapshot: hasNutrition ? Fixture.nutrition() : nil,
            nutritionSource: hasNutrition ? source : nil,
            usesFromPantry: true
        )
    }

    @Test("mixes Open Food Facts, Custom, unknown, and no-data ingredients into separate counts")
    func mixesAllFourCategories() {
        let ingredients = [
            ingredient(source: .openFoodFacts),
            ingredient(source: .openFoodFacts),
            ingredient(source: .custom),
            ingredient(source: nil), // has data, source unrecorded
            ingredient(source: nil, hasNutrition: false) // no data at all
        ]

        let mix = MealStore.provenanceMix(for: ingredients)

        #expect(mix.openFoodFactsCount == 2)
        #expect(mix.customCount == 1)
        #expect(mix.unknownCount == 1)
        #expect(mix.noDataCount == 1)
        #expect(mix.consideredCount == 3, "only ingredients with a known source count toward the described mix")
    }

    @Test("an empty ingredient list produces an all-zero mix, not an error")
    func emptyListIsAllZero() {
        let mix = MealStore.provenanceMix(for: [])
        #expect(mix == NutritionProvenanceMix(openFoodFactsCount: 0, customCount: 0, unknownCount: 0, noDataCount: 0))
    }

    @Test("makeIngredient defaults nutritionSource to Open Food Facts, matching every acquisition path except the pantry one")
    func makeIngredientDefaultsToOpenFoodFacts() {
        let ingredient = MealStore.makeIngredient(
            barcode: "0001",
            productName: "Bread",
            productBrand: nil,
            imageURL: nil,
            nutritionPer100g: Fixture.nutrition(),
            amount: 100,
            unit: Fixture.weightUnit()
        )
        #expect(ingredient.nutritionSource == .openFoodFacts)
    }

    @Test("makeIngredient honors an explicit .custom nutritionSource, e.g. the \"from pantry\" source")
    func makeIngredientHonorsExplicitCustomSource() {
        let ingredient = MealStore.makeIngredient(
            barcode: "0001",
            productName: "Bread",
            productBrand: nil,
            imageURL: nil,
            nutritionPer100g: Fixture.nutrition(),
            amount: 100,
            unit: Fixture.weightUnit(),
            nutritionSource: .custom
        )
        #expect(ingredient.nutritionSource == .custom)
    }

    @Test("makeIngredient records no source at all when there's no usable nutrition data to provenance")
    func makeIngredientRecordsNoSourceWithoutData() {
        let ingredient = MealStore.makeIngredient(
            barcode: "0001",
            productName: "Mystery",
            productBrand: nil,
            imageURL: nil,
            nutritionPer100g: nil,
            amount: 100,
            unit: Fixture.weightUnit(),
            nutritionSource: .custom
        )
        #expect(ingredient.nutritionSnapshot == nil)
        #expect(ingredient.nutritionSource == nil, "provenance is moot with no data to provenance")
    }
}
