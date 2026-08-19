import Foundation
import Testing
import FoodFoundation
@testable import FoodpointKit

/// Covers `AppState.deleteMeal(_:)` (FX-5) — deleting a logged or planned
/// meal outright. Same scope discipline as `MealPantryOrchestrationTests`/
/// `MealIngredientEditTests`: this doesn't re-test `MealStore.removeEntry`'s
/// own removal logic (that's `MealKitTests`' job) or `PantryStore`'s
/// `restore` mutation logic in isolation (`PantryKitTests`' job), just that
/// the two are wired together correctly for the delete case — a `.planned`
/// entry's deletion never touches pantry, and an `.eaten` entry's deletion
/// restores exactly what `markMealEaten` decremented, via the same
/// `consumedAmounts`-precise reconciliation `undoMealEaten`/
/// `updateMealIngredients` use.
@Suite("AppState meal deletion")
struct MealDeletionTests {
    private let barcode = "0000000001"

    private func product(nutrition: Nutrition? = nil) -> Product {
        Product(id: barcode, name: "Test Bread", brand: "Test Brand", imageURL: nil, nutriScoreGrade: nil, categoriesTags: [], nutrition: nutrition)
    }

    private func nutrition(calories: Double = 250) -> Nutrition {
        Nutrition(energyKcal100g: calories, proteins100g: 5, carbohydrates100g: 30, fat100g: 8, sugars100g: 3, fiber100g: 2, sodium100g: 0.5)
    }

    private func unit(quantityPerPackage: Double = 20) -> ProductUnit {
        ProductUnit(label: "slices", quantityPerPackage: quantityPerPackage, gramsPerUnit: 40)
    }

    /// Builds a `LoggedIngredient` the same way `MealStore.makeIngredient`
    /// would, so `impliedUnit`/`impliedNutritionPer100g` round-trip
    /// correctly for the restore path.
    private func ingredient(barcode: String = "0000000001", amount: Double = 4, usesFromPantry: Bool = true) -> LoggedIngredient {
        MealStore.makeIngredient(
            barcode: barcode,
            productName: "Test Bread",
            productBrand: "Test Brand",
            imageURL: nil,
            nutritionPer100g: nutrition(),
            amount: amount,
            unit: unit(),
            usesFromPantry: usesFromPantry
        )
    }

    // MARK: - Planned entries: no pantry involvement

    @Test("deleting a planned entry removes it from the timeline with zero pantry effect")
    func deletingPlannedEntryNeverTouchesPantry() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        let removed = state.deleteMeal(planned.id)

        #expect(removed?.id == planned.id)
        #expect(state.meals.entries.isEmpty, "the entry is gone entirely, not just reverted to planned")
        #expect(state.pantry.items[0].quantity == 20, "planning never touches pantry — deleting a plan must not either")
    }

    // MARK: - Eaten entries: restore exactly what was consumed

    @Test("deleting an eaten entry restores exactly what markMealEaten decremented")
    func deletingEatenEntryRestoresExactDecrement() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items[0].quantity == 16)

        let removed = state.deleteMeal(planned.id)

        #expect(removed?.id == planned.id)
        #expect(state.meals.entries.isEmpty, "the entry is gone entirely")
        #expect(state.pantry.items[0].quantity == 20, "the 4 consumed by the log are restored")
    }

    @Test("deleting an eaten entry after a clamp restores only what was actually taken, not the full logged amount")
    func deletingAfterClampRestoresOnlyActualAmount() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 3))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 10, usesFromPantry: true)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items.isEmpty, "fully depleted by the clamp")

        state.deleteMeal(planned.id)

        #expect(state.pantry.items.first?.quantity == 3, "restores the 3 that were actually taken, not the logged 10")
    }

    @Test("deleting an eaten entry that fully depleted a pantry item re-creates it")
    func deletingEatenEntryThatFullyDepletedItemRecreatesIt() {
        let state = AppState()
        state.pantry.addProduct(product(nutrition: nutrition()), unit: unit(quantityPerPackage: 4))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items.isEmpty, "eating the last of it removed the FoodItem entirely")

        state.deleteMeal(planned.id)

        #expect(state.pantry.items.count == 1)
        #expect(state.pantry.items[0].quantity == 4)
        #expect(state.pantry.items[0].id == barcode)
    }

    // MARK: - usesFromPantry-off ingredients unaffected either way

    @Test("deleting an eaten entry never restores ingredients whose usesFromPantry was off")
    func deletingEatenEntryNeverRestoresToggleOffIngredients() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: false)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items[0].quantity == 20)

        state.deleteMeal(planned.id)

        #expect(state.pantry.items[0].quantity == 20, "nothing was decremented, so nothing should be added either")
    }

    @Test("deleting a planned entry with usesFromPantry-on ingredients still touches nothing — it was never consumed")
    func deletingPlannedEntryWithPantryIngredientsUntouched() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        state.deleteMeal(planned.id)

        #expect(state.pantry.items[0].quantity == 20)
    }

    @Test("a mix of on/off ingredients on an eaten entry only restores the ones with the toggle on")
    func mixedTogglesOnlyRestoreOnIngredients() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let otherBarcode = "0000000002"
        state.pantry.addProduct(
            Product(id: otherBarcode, name: "Test Jam", brand: nil, imageURL: nil, nutriScoreGrade: nil, categoriesTags: [], nutrition: nutrition()),
            unit: unit(quantityPerPackage: 10)
        )
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [
            ingredient(barcode: barcode, amount: 4, usesFromPantry: true),
            ingredient(barcode: otherBarcode, amount: 3, usesFromPantry: false),
        ])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items.first { $0.id == barcode }?.quantity == 16)
        #expect(state.pantry.items.first { $0.id == otherBarcode }?.quantity == 10)

        state.deleteMeal(planned.id)

        #expect(state.pantry.items.first { $0.id == barcode }?.quantity == 20, "restored")
        #expect(state.pantry.items.first { $0.id == otherBarcode }?.quantity == 10, "never touched — usesFromPantry was off")
    }

    // MARK: - No-op for an unknown entry

    @Test("deleting an unknown entry id is a no-op and never touches the pantry")
    func deletingUnknownEntryIsNoOp() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))

        #expect(state.deleteMeal(UUID()) == nil)
        #expect(state.pantry.items[0].quantity == 20)
    }

    @Test("deleting the same entry twice is a no-op the second time")
    func deletingTwiceIsNoOpSecondTime() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        state.markMealEaten(planned.id)

        #expect(state.deleteMeal(planned.id) != nil)
        #expect(state.pantry.items[0].quantity == 20)

        #expect(state.deleteMeal(planned.id) == nil, "already removed — no entry left to find")
        #expect(state.pantry.items[0].quantity == 20, "no further pantry effect from the second, no-op call")
    }
}
