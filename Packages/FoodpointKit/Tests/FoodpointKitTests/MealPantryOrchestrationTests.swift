import Foundation
import Testing
import FoodFoundation
@testable import FoodpointKit

/// Covers `AppState.markMealEaten`/`undoMealEaten` — the cross-domain
/// orchestration that's the only thing worth testing in `FoodpointKit`
/// (package-architecture.md §4.2's "much smaller FoodpointKitTests"; §3.5's
/// sketch). Deliberately doesn't re-test `PantryStore`'s own `consume`/
/// `restore` mutation logic (that's `PantryKitTests`' job) or `MealStore`'s
/// `markEaten`/`undo` state transitions (that's `MealKitTests`' job) beyond
/// what's needed to prove the two are wired together correctly — the cases
/// listed in meals-feature-design.md §14's "FoodpointKit (orchestration
/// only)" section.
@Suite("AppState meal <-> pantry orchestration")
struct MealPantryOrchestrationTests {
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
    /// correctly for `undoMealEaten`'s restore path.
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

    /// Plans then immediately marks-eaten an entry with the given
    /// ingredients — the two-step path the real app takes (composition
    /// editor "Done" -> `meals.plan` -> `markMealEaten`), since
    /// `AppState.markMealEaten` only operates on a `.planned` entry, per
    /// `MealStore.markEaten`'s own contract.
    @discardableResult
    private func planAndMarkEaten(_ state: AppState, ingredients: [LoggedIngredient]) -> UUID {
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: ingredients)
        state.markMealEaten(planned.id)
        return planned.id
    }

    // MARK: - markMealEaten decrements only usesFromPantry ingredients

    @Test("marking a meal eaten decrements the pantry only for ingredients with usesFromPantry on")
    func markMealEatenDecrementsOnlyPantryIngredients() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))

        planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        #expect(state.pantry.items[0].quantity == 16)
    }

    @Test("ingredients with usesFromPantry off never touch inventory")
    func usesFromPantryOffNeverTouchesInventory() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))

        planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: false)])

        #expect(state.pantry.items[0].quantity == 20, "untouched — this ingredient wasn't claimed to come from the pantry")
    }

    @Test("a mix of on/off ingredients only decrements the ones with the toggle on")
    func mixedTogglesOnlyDecrementOnIngredients() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let otherBarcode = "0000000002"
        state.pantry.addProduct(
            Product(id: otherBarcode, name: "Test Jam", brand: nil, imageURL: nil, nutriScoreGrade: nil, categoriesTags: [], nutrition: nutrition()),
            unit: unit(quantityPerPackage: 10)
        )

        planAndMarkEaten(state, ingredients: [
            ingredient(barcode: barcode, amount: 4, usesFromPantry: true),
            ingredient(barcode: otherBarcode, amount: 3, usesFromPantry: false),
        ])

        #expect(state.pantry.items.first { $0.id == barcode }?.quantity == 16)
        #expect(state.pantry.items.first { $0.id == otherBarcode }?.quantity == 10, "toggle off — untouched")
    }

    // MARK: - Insufficient stock clamps rather than blocking

    @Test("insufficient stock clamps to zero instead of going negative or blocking")
    func insufficientStockClampsToZero() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 3))

        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 10, usesFromPantry: true)])

        #expect(state.pantry.items.isEmpty, "clamped all the way to zero, which deletes the item")
        #expect(state.meals.entries.first(where: { $0.id == entryID })?.status == .eaten, "logging itself is never blocked by insufficient stock")
    }

    @Test("insufficientStockIngredients reports the ingredient that came up short")
    func insufficientStockIngredientsReportsShortfall() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 3))

        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 10, usesFromPantry: true)])

        #expect(state.insufficientStockIngredients(for: entryID) == ["Test Bread"])
    }

    @Test("insufficientStockIngredients is empty when stock fully covered every ingredient")
    func insufficientStockIngredientsEmptyWhenFullyCovered() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))

        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        #expect(state.insufficientStockIngredients(for: entryID).isEmpty)
    }

    // MARK: - undoMealEaten restores exactly what was decremented

    @Test("undo restores exactly what markMealEaten decremented")
    func undoRestoresExactDecrement() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        #expect(state.pantry.items[0].quantity == 16)

        state.undoMealEaten(entryID)

        #expect(state.pantry.items[0].quantity == 20)
        #expect(state.meals.entries.first?.status == .planned)
    }

    @Test("undo after a clamp restores only what was actually taken, not the full logged amount")
    func undoAfterClampRestoresOnlyActualAmount() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 3))
        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 10, usesFromPantry: true)])
        #expect(state.pantry.items.isEmpty, "fully depleted by the clamp")

        state.undoMealEaten(entryID)

        #expect(state.pantry.items.first?.quantity == 3, "restores the 3 that were actually taken, not the logged 10")
    }

    @Test("undo never restores ingredients whose usesFromPantry was off")
    func undoNeverRestoresToggleOffIngredients() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: false)])
        #expect(state.pantry.items[0].quantity == 20)

        state.undoMealEaten(entryID)

        #expect(state.pantry.items[0].quantity == 20, "nothing was decremented, so nothing should be added either")
    }

    // MARK: - The §4.3 edge case: undo re-creates a fully-depleted item

    @Test("undoing a meal that fully depleted a pantry item re-creates it, not just bumps a nonexistent quantity")
    func undoRecreatesFullyDepletedItem() {
        let state = AppState()
        state.pantry.addProduct(product(nutrition: nutrition()), unit: unit(quantityPerPackage: 4))
        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        #expect(state.pantry.items.isEmpty, "eating the last of it removed the FoodItem entirely")

        state.undoMealEaten(entryID)

        #expect(state.pantry.items.count == 1)
        #expect(state.pantry.items[0].quantity == 4)
        #expect(state.pantry.items[0].id == barcode)
    }

    @Test("eating the last unit removes the pantry item but leaves the meal's history intact")
    func eatingLastUnitLeavesHistoryIntact() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 4))
        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        #expect(state.pantry.items.isEmpty)
        let entry = state.meals.entries.first(where: { $0.id == entryID })
        #expect(entry?.status == .eaten)
        #expect(entry?.ingredients.first?.amount == 4, "the logged entry itself is untouched by the pantry side effect")
    }

    // MARK: - Frozen history: pantry-side nutrition edits never leak into an eaten entry

    @Test("editing a product's nutrition in PantryKit does not alter a MealKit entry already marked eaten")
    func editingPantryNutritionDoesNotAlterEatenEntry() {
        let state = AppState()
        state.pantry.addProduct(product(nutrition: nutrition(calories: 250)), unit: unit(quantityPerPackage: 20))
        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 4, usesFromPantry: true)])
        let originalSnapshot = state.meals.entries.first(where: { $0.id == entryID })?.ingredients.first?.nutritionSnapshot

        let corrected = NutritionVariant(name: "Corrected", nutrition: nutrition(calories: 999), source: .custom)
        state.pantry.setDefaultNutritionVariant(corrected, forBarcode: barcode)

        let entryAfterEdit = state.meals.entries.first(where: { $0.id == entryID })
        #expect(entryAfterEdit?.ingredients.first?.nutritionSnapshot == originalSnapshot, "MealKit's frozen snapshot is untouched by a live PantryKit edit")
        #expect(state.pantry.items[0].product.nutrition?.energyKcal100g == 999, "meanwhile the live pantry item did pick up the correction")
    }

    // MARK: - No-op contracts, matching MealStore.markEaten/undo's own

    @Test("markMealEaten on an unknown entry is a no-op and never touches the pantry")
    func markMealEatenUnknownEntryIsNoOp() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))

        #expect(state.markMealEaten(UUID()) == nil)
        #expect(state.pantry.items[0].quantity == 20)
    }

    @Test("undoMealEaten on an entry that was never marked eaten is a no-op")
    func undoMealEatenOnPlannedEntryIsNoOp() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Test Meal", date: Date(), slot: .breakfast, ingredients: [ingredient(amount: 4)])

        #expect(state.undoMealEaten(planned.id) == nil)
        #expect(state.pantry.items[0].quantity == 20)
    }

    // MARK: - Planning has zero effect until tick-off (MK-5, meals-feature-design.md §5)

    @Test("planning a meal for a future date never touches pantry quantities")
    func planningNeverTouchesPantry() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        state.meals.plan(name: "Future Meal", date: tomorrow, slot: .dinner, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        #expect(state.pantry.items[0].quantity == 20, "planning must have zero pantry effect until ticked off")
    }

    @Test("planning a meal for a future date never affects today's eaten totals")
    func planningNeverAffectsTodaysEatenTotal() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        state.meals.plan(name: "Future Meal", date: tomorrow, slot: .dinner, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        #expect(state.meals.dayTotal(for: today).eaten.consideredCount == 0, "a plan for a different day must not leak into today's eaten total")
    }

    // MARK: - stockShortfalls: soft signal, computed live, never reserving

    @Test("stockShortfalls reports a planned entry's ingredient that exceeds current pantry stock")
    func stockShortfallsReportsPlannedShortfall() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 3))
        let planned = state.meals.plan(name: "Future Meal", date: Date(), slot: .dinner, ingredients: [ingredient(amount: 10, usesFromPantry: true)])

        let shortfalls = state.stockShortfalls(for: planned.id)

        #expect(shortfalls.count == 1)
        #expect(shortfalls[0].needed == 10)
        #expect(shortfalls[0].available == 3)
        #expect(state.pantry.items[0].quantity == 3, "checking the signal must not reserve or otherwise touch pantry stock")
    }

    @Test("stockShortfalls is empty once the plan is fully covered by pantry stock")
    func stockShortfallsEmptyWhenCovered() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 20))
        let planned = state.meals.plan(name: "Future Meal", date: Date(), slot: .dinner, ingredients: [ingredient(amount: 4, usesFromPantry: true)])

        #expect(state.stockShortfalls(for: planned.id).isEmpty)
    }

    @Test("stockShortfalls is empty for an entry already marked eaten — its pantry effect already happened")
    func stockShortfallsEmptyOnceEaten() {
        let state = AppState()
        state.pantry.addProduct(product(), unit: unit(quantityPerPackage: 3))
        let entryID = planAndMarkEaten(state, ingredients: [ingredient(amount: 10, usesFromPantry: true)])

        #expect(state.stockShortfalls(for: entryID).isEmpty)
    }

    @Test("stockShortfalls is empty for an unknown entry id")
    func stockShortfallsEmptyForUnknownID() {
        let state = AppState()
        #expect(state.stockShortfalls(for: UUID()).isEmpty)
    }
}
