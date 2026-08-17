import Foundation
import Testing
import FoodFoundation
@testable import MealKit

/// Covers the pure, network-free logic added for the composition editor
/// (MK-2, `Foodpoint/Views/MealCompositionEditorView.swift`): building/
/// re-building a `LoggedIngredient` locally as amounts are edited
/// (`MealStore.makeIngredient`, `LoggedIngredient.impliedUnit`/
/// `.impliedNutritionPer100g`), the public `MealStore.completeness(for:)`
/// used by the editor's live footer, and the "from history"/"first-time
/// barcode" acquisition helpers (`recentlyUsedIngredients`,
/// `lastKnownUnit(forBarcode:)`).
@Suite("Composition editor support logic")
struct IngredientCompositionTests {
    @Test("makeIngredient computes grams and scaled nutrition the same way resolveIngredient does")
    func makeIngredientMatchesResolveIngredient() {
        let ingredient = MealStore.makeIngredient(
            barcode: "0001",
            productName: "Bread",
            productBrand: "Acme",
            imageURL: nil,
            nutritionPer100g: Fixture.nutrition(calories: 200),
            amount: 2,
            unit: Fixture.countUnit(gramsPerUnit: 50)
        )
        #expect(ingredient.gramsResolved == 100) // 2 slices * 50g
        #expect(ingredient.nutritionSnapshot?.energyKcal100g == 200) // 200 kcal/100g * (100g/100)
        #expect(ingredient.usesFromPantry == true, "defaults on per meals-feature-design.md §4.4")
    }

    @Test("makeIngredient reports a nil nutrition snapshot for effectively-empty or missing data, not a zero")
    func makeIngredientHonestAboutMissingData() {
        let empty = MealStore.makeIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, nutritionPer100g: Fixture.emptyNutrition(), amount: 1, unit: Fixture.countUnit())
        #expect(empty.nutritionSnapshot == nil)

        let missing = MealStore.makeIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, nutritionPer100g: nil, amount: 1, unit: Fixture.countUnit())
        #expect(missing.nutritionSnapshot == nil)
    }

    @Test("impliedUnit/impliedNutritionPer100g round-trip back through makeIngredient for a new amount, without a network call")
    func roundTripThroughImpliedFields() {
        // Simulate a "from history" pick: an ingredient logged at 2 slices,
        // then the editor bumping the amount to 4 slices using only its own
        // implied fields — no productResolver involved anywhere here.
        let original = MealStore.makeIngredient(
            barcode: "0001",
            productName: "Bread",
            productBrand: "Acme",
            imageURL: nil,
            nutritionPer100g: Fixture.nutrition(calories: 200),
            amount: 2,
            unit: Fixture.countUnit(gramsPerUnit: 50)
        )

        let edited = MealStore.makeIngredient(
            barcode: original.barcode,
            productName: original.productName,
            productBrand: original.productBrand,
            imageURL: original.imageURL,
            nutritionPer100g: original.impliedNutritionPer100g,
            amount: 4,
            unit: original.impliedUnit,
            usesFromPantry: original.usesFromPantry
        )

        #expect(edited.gramsResolved == 200) // 4 slices * 50g/slice, the same ratio as the original
        #expect(edited.nutritionSnapshot?.energyKcal100g == 400) // 200 kcal/100g * (200g/100)
    }

    @Test("impliedUnit is nil-gramsPerUnit when amount is zero, since the per-unit ratio is undefined")
    func impliedUnitUndefinedAtZeroAmount() {
        let ingredient = LoggedIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, amount: 0, unitLabel: "slices", gramsResolved: 0, nutritionSnapshot: nil, usesFromPantry: true)
        #expect(ingredient.impliedUnit.gramsPerUnit == nil)
    }

    @Test("impliedNutritionPer100g is nil when there was no nutrition snapshot to begin with")
    func impliedNutritionNilWhenSnapshotNil() {
        let ingredient = LoggedIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, amount: 2, unitLabel: "slices", gramsResolved: 100, nutritionSnapshot: nil, usesFromPantry: true)
        #expect(ingredient.impliedNutritionPer100g == nil)
    }

    @Test("MealStore.completeness(for:) is usable directly, ahead of any MealEntry existing, for the editor's live footer")
    func completenessUsableStandalone() {
        let complete = MealStore.makeIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, nutritionPer100g: Fixture.nutrition(calories: 100), amount: 1, unit: Fixture.weightUnit())
        let missing = MealStore.makeIngredient(barcode: "0002", productName: nil, productBrand: nil, imageURL: nil, nutritionPer100g: nil, amount: 1, unit: Fixture.weightUnit())

        let completeness = MealStore.completeness(for: [complete, missing])
        #expect(completeness.consideredCount == 2)
        #expect(completeness.missingCount == 1)
        #expect(!completeness.isComplete)
    }

    @Test("recentlyUsedIngredients dedupes by barcode, most-recently-logged entry first, with no network call")
    func recentlyUsedIngredientsDedupesByRecency() {
        let store = MealStore()
        let bread = MealStore.makeIngredient(barcode: "bread", productName: "Old Bread", productBrand: nil, imageURL: nil, nutritionPer100g: Fixture.nutrition(), amount: 1, unit: Fixture.countUnit())
        let egg = MealStore.makeIngredient(barcode: "egg", productName: "Egg", productBrand: nil, imageURL: nil, nutritionPer100g: Fixture.nutrition(), amount: 2, unit: Fixture.countUnit(label: "eggs", gramsPerUnit: 50))
        let newerBread = MealStore.makeIngredient(barcode: "bread", productName: "New Bread", productBrand: nil, imageURL: nil, nutritionPer100g: Fixture.nutrition(), amount: 3, unit: Fixture.countUnit())

        store.logEaten(name: "Old Meal", date: day(0), slot: .breakfast, ingredients: [bread, egg])
        store.logEaten(name: "New Meal", date: day(1), slot: .lunch, ingredients: [newerBread])

        let history = store.recentlyUsedIngredients()
        #expect(history.count == 2, "bread appears once, deduped by barcode")
        #expect(history.first?.barcode == "bread", "the more recently logged entry's copy wins")
        #expect(history.first?.productName == "New Bread")
    }

    @Test("recentlyUsedIngredients is empty for a fresh store")
    func recentlyUsedIngredientsEmptyInitially() {
        let store = MealStore()
        #expect(store.recentlyUsedIngredients().isEmpty)
    }

    @Test("lastKnownUnit reconstructs a logged ingredient's unit from the most recent matching entry")
    func lastKnownUnitFromLoggedEntry() {
        let store = MealStore()
        let ingredient = MealStore.makeIngredient(barcode: "bread", productName: "Bread", productBrand: nil, imageURL: nil, nutritionPer100g: Fixture.nutrition(), amount: 2, unit: Fixture.countUnit(label: "slices", gramsPerUnit: 50))
        store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [ingredient])

        let unit = store.lastKnownUnit(forBarcode: "bread")
        #expect(unit?.label == "slices")
        #expect(unit?.gramsPerUnit == 50)
    }

    @Test("lastKnownUnit falls back to a template's unit when the barcode only appears there")
    func lastKnownUnitFromTemplateOnly() {
        let store = MealStore()
        let templateIngredient = TemplateIngredient(barcode: "rice", productName: "Rice", productBrand: nil, imageURL: nil, amount: 150, unit: Fixture.weightUnit())
        store.addTemplate(MealTemplate(name: "Rice Bowl", defaultSlot: .lunch, ingredients: [templateIngredient]))

        let unit = store.lastKnownUnit(forBarcode: "rice")
        #expect(unit?.label == "g")
    }

    @Test("lastKnownUnit is nil for a barcode this store has never seen, signaling the editor to prompt unit setup")
    func lastKnownUnitNilForUnseenBarcode() {
        let store = MealStore()
        #expect(store.lastKnownUnit(forBarcode: "never-seen") == nil)
    }
}
