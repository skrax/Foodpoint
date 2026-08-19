import Foundation
import Testing
import FoodFoundation
@testable import FoodpointKit

/// Covers `AppState.updateMealIngredients(_:ingredients:)` (FX-4) — editing
/// an already-logged/planned entry's ingredients. Same scope discipline as
/// `MealPantryOrchestrationTests`: this doesn't re-test `PantryStore`'s own
/// `consume`/`restore` mutation logic or `MealStore`'s `updateEntry` in
/// isolation, just that the two are wired together correctly for the edit
/// case — reversing the old ingredient list's pantry consumption and
/// applying the new list's, exactly, for an `.eaten` entry, and doing
/// nothing pantry-related at all for a `.planned` one.
@Suite("AppState meal ingredient editing")
struct MealIngredientEditTests {
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
    /// correctly for the reconciliation's restore path.
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

    @Test("editing a planned entry's ingredients replaces them via updateEntry with zero pantry effect")
    func editingPlannedEntryNeverTouchesPantry() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        let newIngredients = [ingredient(amount: 9, usesFromPantry: true)]
        let updated = state.updateMealIngredients(planned.id, ingredients: newIngredients)

        #expect(updated?.ingredients.first?.amount == 9)
        #expect(state.meals.entries.first(where: { $0.id == planned.id })?.ingredients.first?.amount == 9)
        #expect(state.pantry.items[0].quantity == 20, "planning never touches pantry — editing a plan must not either")
    }

    @Test("editing a planned entry keeps its status as planned")
    func editingPlannedEntryKeepsStatus() {
        let state = AppState()
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4)])

        let updated = state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 2)])

        #expect(updated?.status == .planned)
    }

    // MARK: - Eaten entries: reverse old consumption, apply new

    @Test("editing an eaten entry's ingredients reverses the old amount and applies the new one")
    func editingEatenEntryReconcilesPantry() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items[0].quantity == 16, "4 consumed by the original log")

        state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 9, usesFromPantry: true)])

        #expect(state.pantry.items[0].quantity == 11, "4 restored back to 20, then 9 freshly consumed down to 11")
    }

    @Test("editing an eaten entry down to a smaller amount restores the difference")
    func editingEatenEntryToSmallerAmountRestoresDifference() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 8, usesFromPantry: true)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items[0].quantity == 12)

        state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 2, usesFromPantry: true)])

        #expect(state.pantry.items[0].quantity == 18, "8 restored to 20, then 2 freshly consumed down to 18")
    }

    @Test("editing an eaten entry updates the stored ingredients and keeps it eaten")
    func editingEatenEntryUpdatesIngredientsAndStatus() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        state.markMealEaten(planned.id)

        let updated = state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 9, usesFromPantry: true)])

        #expect(updated?.status == .eaten)
        #expect(updated?.ingredients.first?.amount == 9)
        #expect(state.meals.entries.first(where: { $0.id == planned.id })?.ingredients.first?.amount == 9)
    }

    // MARK: - Insufficient stock on the new list still clamps softly

    @Test("insufficient stock on the new ingredient list clamps to zero rather than going negative")
    func insufficientStockOnNewListClampsToZero() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 5))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 3, usesFromPantry: true)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items[0].quantity == 2, "3 consumed, 2 left")

        // Old (3) is restored first, bringing stock back to 5; the new
        // ingredient then asks for 10, which clamps to whatever's there.
        let updated = state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 10, usesFromPantry: true)])

        #expect(state.pantry.items.isEmpty, "clamped all the way to zero, which deletes the item")
        #expect(updated?.status == .eaten, "editing is never blocked by insufficient stock")
        #expect(state.insufficientStockIngredients(for: planned.id).contains("Test Bread"), "the shortfall bookkeeping reflects the newly-consumed amount")
    }

    @Test("editing an eaten entry that fully depletes stock still lets a later undo re-create the item")
    func editingToFullDepletionStillAllowsLaterUndoToRecreate() {
        let state = AppState()
        state.pantry.addProduct(product(nutrition: nutrition()), unit: unit(quantityPerPackage: 5))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 2, usesFromPantry: true)])
        state.markMealEaten(planned.id)

        state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 5, usesFromPantry: true)])
        #expect(state.pantry.items.isEmpty)

        state.undoMealEaten(planned.id)

        #expect(state.pantry.items.count == 1)
        #expect(state.pantry.items[0].quantity == 5)
    }

    // MARK: - usesFromPantry-off ingredients never touch inventory, old or new

    @Test("usesFromPantry off on the OLD ingredient means nothing is restored for it")
    func usesFromPantryOffOnOldIngredientIsNotRestored() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: false)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items[0].quantity == 20, "never consumed since usesFromPantry was off")

        state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 4, usesFromPantry: false)])

        #expect(state.pantry.items[0].quantity == 20, "still untouched — nothing to restore, nothing new to consume")
    }

    @Test("usesFromPantry off on the NEW ingredient means nothing is consumed for it, even though the old one was")
    func usesFromPantryOffOnNewIngredientIsNotConsumed() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        state.markMealEaten(planned.id)
        #expect(state.pantry.items[0].quantity == 16)

        state.updateMealIngredients(planned.id, ingredients: [ingredient(amount: 4, usesFromPantry: false)])

        #expect(state.pantry.items[0].quantity == 20, "old consumption reversed, and the new ingredient never draws since its toggle is off")
    }

    @Test("a mix of on/off ingredients on both old and new lists only reconciles the ones with the toggle on")
    func mixedTogglesOnlyReconcileOnIngredients() {
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

        state.updateMealIngredients(planned.id, ingredients: [
            ingredient(barcode: barcode, amount: 6, usesFromPantry: true),
            ingredient(barcode: otherBarcode, amount: 5, usesFromPantry: true),
        ])

        #expect(state.pantry.items.first { $0.id == barcode }?.quantity == 14, "4 restored to 20, then 6 consumed")
        #expect(state.pantry.items.first { $0.id == otherBarcode }?.quantity == 5, "newly turned on — consumes fresh from 10")
    }

    // MARK: - No-op for an unknown entry

    @Test("updateMealIngredients on an unknown entry id is a no-op and never touches the pantry")
    func updateMealIngredientsUnknownEntryIsNoOp() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))

        #expect(state.updateMealIngredients(UUID(), ingredients: [ingredient(amount: 4)]) == nil)
        #expect(state.pantry.items[0].quantity == 20)
    }
}
