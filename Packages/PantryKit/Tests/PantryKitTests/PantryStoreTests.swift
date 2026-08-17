import Foundation
import Testing
import FoodFoundation
@testable import PantryKit

@Suite("PantryStore")
struct PantryStoreTests {
    private let barcode = "0000000001"

    private func product(nutrition: Nutrition? = nil) -> Product {
        Product(id: barcode, name: "Test Product", brand: "Test Brand", imageURL: nil, nutriScoreGrade: nil, categoriesTags: [], nutrition: nutrition)
    }

    private func nutrition(calories: Double = 250) -> Nutrition {
        Nutrition(energyKcal100g: calories, proteins100g: 5, carbohydrates100g: 30, fat100g: 8, sugars100g: 3, fiber100g: 2, sodium100g: 0.5)
    }

    private func unit(quantityPerPackage: Double = 1) -> ProductUnit {
        ProductUnit(label: "bars", quantityPerPackage: quantityPerPackage, gramsPerUnit: 40)
    }

    // MARK: - addProduct

    @Test("adding a brand-new barcode creates one item with the package quantity")
    func addProductCreatesNewItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 20))

        #expect(state.items.count == 1)
        #expect(state.items[0].quantity == 20)
        #expect(state.unitConfigs[barcode]?.quantityPerPackage == 20)
    }

    @Test("re-adding a known barcode increments quantity instead of duplicating")
    func addProductIncrementsExistingItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 20))
        state.addProduct(product(), unit: unit(quantityPerPackage: 20))

        #expect(state.items.count == 1)
        #expect(state.items[0].quantity == 40)
    }

    @Test("the unit passed on first save becomes the default, later scans don't overwrite it")
    func addProductEstablishesDefaultUnitOnce() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 20))
        state.addProduct(product(), unit: unit(quantityPerPackage: 999)) // different unit, ignored for default purposes

        #expect(state.unitConfigs[barcode]?.quantityPerPackage == 20)
    }

    @Test("non-empty Open Food Facts nutrition becomes the default on first save")
    func addProductEstablishesNutritionWhenNonEmpty() {
        let state = PantryStore()
        state.addProduct(product(nutrition: nutrition()), unit: unit())

        #expect(state.nutritionConfigs[barcode]?.source == .openFoodFacts)
        #expect(state.nutritionConfigs[barcode]?.nutrition.energyKcal100g == 250)
        #expect(state.items[0].product.nutrition?.energyKcal100g == 250)
    }

    @Test("empty Open Food Facts nutrition does not establish a default")
    func addProductSkipsEmptyNutrition() {
        let state = PantryStore()
        let empty = Nutrition(energyKcal100g: 0, proteins100g: 0, carbohydrates100g: 0, fat100g: 0, sugars100g: 0, fiber100g: 0, sodium100g: 0)
        state.addProduct(product(nutrition: empty), unit: unit())

        #expect(state.nutritionConfigs[barcode] == nil)
        #expect(state.items[0].product.nutrition == nil)
    }

    @Test("a pre-existing default nutrition variant is not overwritten by a later scan's Open Food Facts data")
    func addProductDoesNotOverwriteExistingNutritionDefault() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit())
        let custom = NutritionVariant(name: "My Values", nutrition: nutrition(calories: 300), source: .custom)
        state.setDefaultNutritionVariant(custom, forBarcode: barcode)

        state.addProduct(product(nutrition: nutrition(calories: 250)), unit: unit())

        #expect(state.nutritionConfigs[barcode]?.source == .custom)
        #expect(state.nutritionConfigs[barcode]?.nutrition.energyKcal100g == 300)
    }

    // MARK: - setQuantity

    @Test("setting quantity to zero or below removes the item")
    func setQuantityToZeroRemovesItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit())
        state.setQuantity(0, forItemID: barcode)
        #expect(state.items.isEmpty)
    }

    @Test("setting a positive quantity updates it in place")
    func setQuantityUpdatesInPlace() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit())
        state.setQuantity(7, forItemID: barcode)
        #expect(state.items.first?.quantity == 7)
    }

    // MARK: - Package-size variants

    @Test("addUnitVariant, updateVariant, removeVariant, makeDefault")
    func packageVariantLifecycle() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 15)) // becomes default

        let small = ProductUnit(name: "Small", label: "bars", quantityPerPackage: 10, gramsPerUnit: 40)
        state.addUnitVariant(small, forBarcode: barcode)
        #expect(state.allVariants(forBarcode: barcode).count == 2)

        // removeVariant refuses to delete the default
        let defaultID = state.unitConfigs[barcode]!.id
        state.removeVariant(defaultID, forBarcode: barcode)
        #expect(state.allVariants(forBarcode: barcode).count == 2)

        // makeDefault promotes the alternate and demotes the old default
        state.makeDefault(small.id, forBarcode: barcode)
        #expect(state.unitConfigs[barcode]?.id == small.id)
        #expect(state.unitVariants[barcode]?.contains { $0.id == defaultID } == true)

        // updateVariant edits the (new) default in place
        var renamed = small
        renamed.name = "Renamed"
        state.updateVariant(renamed, forBarcode: barcode)
        #expect(state.unitConfigs[barcode]?.name == "Renamed")

        // removeVariant now succeeds on the demoted (non-default) variant
        state.removeVariant(defaultID, forBarcode: barcode)
        #expect(state.allVariants(forBarcode: barcode).count == 1)
    }

    @Test("renameUnitLabel updates the default, every alternate, and the active item's unit at once")
    func renameUnitLabelUpdatesEveryVariant() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 15)) // becomes default, label "bars"

        let small = ProductUnit(name: "Small", label: "bars", quantityPerPackage: 10, gramsPerUnit: 40)
        state.addUnitVariant(small, forBarcode: barcode)

        state.renameUnitLabel("slices", forBarcode: barcode)

        #expect(state.unitConfigs[barcode]?.label == "slices")
        #expect(state.unitVariants[barcode]?.allSatisfy { $0.label == "slices" } == true)
        #expect(state.items[0].unit.label == "slices")
    }

    @Test("renameUnitLabel is a no-op for weight-tracked units")
    func renameUnitLabelNoOpForWeightTracked() {
        let state = PantryStore()
        let weightUnit = ProductUnit(label: "g", quantityPerPackage: 500, gramsPerUnit: 1)
        state.addProduct(product(), unit: weightUnit)

        state.renameUnitLabel("bogus", forBarcode: barcode)

        #expect(state.unitConfigs[barcode]?.label == "g")
    }

    @Test("updateVariant refreshes the saved item's unit when it's the active one")
    func updateVariantSyncsActiveItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 15))
        var updated = state.unitConfigs[barcode]!
        updated.gramsPerUnit = 55
        state.updateVariant(updated, forBarcode: barcode)
        #expect(state.items[0].unit.gramsPerUnit == 55)
    }

    // MARK: - Nutrition variants

    @Test("addNutritionVariant, updateNutritionVariant, removeNutritionVariant, makeNutritionDefault mirror the package-variant lifecycle")
    func nutritionVariantLifecycle() {
        let state = PantryStore()
        state.addProduct(product(nutrition: nutrition()), unit: unit()) // OFF variant becomes default

        let custom = NutritionVariant(name: "My Values", nutrition: nutrition(calories: 300), source: .custom)
        state.addNutritionVariant(custom, forBarcode: barcode)
        #expect(state.allNutritionVariants(forBarcode: barcode).count == 2)

        let defaultID = state.nutritionConfigs[barcode]!.id
        state.removeNutritionVariant(defaultID, forBarcode: barcode)
        #expect(state.allNutritionVariants(forBarcode: barcode).count == 2, "the default must not be removable")

        state.makeNutritionDefault(custom.id, forBarcode: barcode)
        #expect(state.nutritionConfigs[barcode]?.id == custom.id)
        #expect(state.nutritionVariants[barcode]?.contains { $0.id == defaultID } == true)
        #expect(state.items[0].product.nutrition?.energyKcal100g == 300, "the item's displayed nutrition follows the new default")
    }

    @Test("setDefaultNutritionVariant demotes the previous default rather than discarding it")
    func setDefaultNutritionVariantPreservesPrevious() {
        let state = PantryStore()
        state.addProduct(product(nutrition: nutrition()), unit: unit())
        let offID = state.nutritionConfigs[barcode]!.id

        let custom = NutritionVariant(name: "My Values", nutrition: nutrition(calories: 300), source: .custom)
        state.setDefaultNutritionVariant(custom, forBarcode: barcode)

        #expect(state.nutritionConfigs[barcode]?.id == custom.id)
        #expect(state.nutritionVariants[barcode]?.contains { $0.id == offID } == true)
    }

    @Test("refreshNutritionVariant updates the default in place without changing which is default")
    func refreshNutritionVariantUpdatesDefaultInPlace() {
        let state = PantryStore()
        state.addProduct(product(nutrition: nutrition(calories: 250)), unit: unit())
        let offID = state.nutritionConfigs[barcode]!.id

        let refreshed = NutritionVariant(id: offID, name: "Open Food Facts", nutrition: nutrition(calories: 260), source: .openFoodFacts)
        state.refreshNutritionVariant(refreshed, forBarcode: barcode)

        #expect(state.nutritionConfigs[barcode]?.id == offID, "still the default")
        #expect(state.nutritionConfigs[barcode]?.nutrition.energyKcal100g == 260, "but with the refreshed numbers")
    }

    @Test("refreshNutritionVariant appends an unknown variant as an alternate without touching the default")
    func refreshNutritionVariantAppendsUnknownAsAlternate() {
        let state = PantryStore()
        let custom = NutritionVariant(name: "My Values", nutrition: nutrition(calories: 300), source: .custom)
        state.addProduct(product(), unit: unit())
        state.setDefaultNutritionVariant(custom, forBarcode: barcode)

        let brandNewOFF = NutritionVariant(name: "Open Food Facts", nutrition: nutrition(calories: 250), source: .openFoodFacts)
        state.refreshNutritionVariant(brandNewOFF, forBarcode: barcode)

        #expect(state.nutritionConfigs[barcode]?.id == custom.id, "default is untouched")
        #expect(state.nutritionVariants[barcode]?.contains { $0.id == brandNewOFF.id } == true)
    }

    // MARK: - pendingNutritionUpdate

    @Test("nil/empty Open Food Facts data has nothing pending")
    func pendingUpdateNilForEmptyData() {
        let state = PantryStore()
        #expect(state.pendingNutritionUpdate(from: nil, forBarcode: barcode) == nil)

        let empty = Nutrition(energyKcal100g: 0, proteins100g: nil, carbohydrates100g: nil, fat100g: nil, sugars100g: nil, fiber100g: nil, sodium100g: nil)
        #expect(state.pendingNutritionUpdate(from: empty, forBarcode: barcode) == nil)
    }

    @Test("matching what's already remembered has nothing pending")
    func pendingUpdateNilWhenUnchanged() {
        let state = PantryStore()
        state.addProduct(product(nutrition: nutrition()), unit: unit())
        #expect(state.pendingNutritionUpdate(from: nutrition(), forBarcode: barcode) == nil)
    }

    @Test("new or changed Open Food Facts data is offered as a pending update")
    func pendingUpdateNonNilWhenChanged() {
        let state = PantryStore()
        state.addProduct(product(nutrition: nutrition(calories: 250)), unit: unit())
        let update = state.pendingNutritionUpdate(from: nutrition(calories: 999), forBarcode: barcode)
        #expect(update?.nutrition.energyKcal100g == 999)
        #expect(update?.source == .openFoodFacts)
        #expect(update?.id == state.nutritionConfigs[barcode]?.id, "reuses the existing OFF variant's id rather than minting a new one")
    }

    @Test("a barcode with no stored data yet still offers first-time Open Food Facts data")
    func pendingUpdateForFirstTimeData() {
        let state = PantryStore()
        let update = state.pendingNutritionUpdate(from: nutrition(), forBarcode: barcode)
        #expect(update?.nutrition.energyKcal100g == 250)
    }

    // MARK: - consume (MK-3, meal-driven pantry decrement)

    @Test("consume decrements a known item's quantity and returns the full amount taken")
    func consumeDecrementsKnownItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 10))

        let consumed = state.consume(barcode: barcode, amount: 4)

        #expect(consumed == 4)
        #expect(state.items[0].quantity == 6)
    }

    @Test("consume clamps to zero rather than going negative when stock is insufficient")
    func consumeClampsToZeroOnInsufficientStock() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 3))

        let consumed = state.consume(barcode: barcode, amount: 10)

        #expect(consumed == 3, "reports only the amount actually taken, not what was requested")
        #expect(state.items.isEmpty, "clamping to zero routes through setQuantity's existing delete-at-zero behavior")
    }

    @Test("consuming the exact remaining amount removes the item, same as setQuantity(0, ...)")
    func consumeExactRemainingRemovesItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 5))

        let consumed = state.consume(barcode: barcode, amount: 5)

        #expect(consumed == 5)
        #expect(state.items.isEmpty)
    }

    @Test("consume on an unknown barcode is a no-op returning zero")
    func consumeUnknownBarcodeReturnsZero() {
        let state = PantryStore()
        #expect(state.consume(barcode: "ghost", amount: 5) == 0)
    }

    @Test("consume with a non-positive amount is a no-op returning zero")
    func consumeNonPositiveAmountReturnsZero() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 5))
        #expect(state.consume(barcode: barcode, amount: 0) == 0)
        #expect(state.consume(barcode: barcode, amount: -1) == 0)
        #expect(state.items[0].quantity == 5, "neither call mutated the item")
    }

    // MARK: - restore (MK-3, undo's pantry side effect)

    @Test("restore adds back to an item that still exists rather than duplicating it")
    func restoreAddsToExistingItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 10))
        state.consume(barcode: barcode, amount: 4)

        state.restore(product: product(), unit: unit(), amount: 4)

        #expect(state.items.count == 1)
        #expect(state.items[0].quantity == 10)
    }

    @Test("restore re-creates an item that was fully depleted (and thus deleted)")
    func restoreRecreatesFullyDepletedItem() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 5))
        state.consume(barcode: barcode, amount: 5)
        #expect(state.items.isEmpty, "sanity check: fully depleted")

        state.restore(product: product(), unit: unit(), amount: 5)

        #expect(state.items.count == 1)
        #expect(state.items[0].quantity == 5)
        #expect(state.items[0].unit.label == "bars", "re-created using the barcode's remembered unit config")
    }

    @Test("restore prefers the barcode's remembered unitConfigs entry over the unit it was passed")
    func restoreUsesRememberedUnitConfigsOverPassedUnit() {
        let state = PantryStore()
        state.addProduct(product(), unit: unit(quantityPerPackage: 5)) // establishes "bars" as the remembered default
        state.consume(barcode: barcode, amount: 5)

        let differentUnit = ProductUnit(label: "slices", quantityPerPackage: 1, gramsPerUnit: 20)
        state.restore(product: product(), unit: differentUnit, amount: 5)

        #expect(state.items[0].unit.label == "bars", "unitConfigs is the authoritative unit, not whatever the caller reconstructed")
    }

    @Test("restore falls back to the passed unit when there's no remembered unitConfigs entry at all")
    func restoreFallsBackToPassedUnitWhenNoConfigRemembered() {
        let state = PantryStore()
        let freshUnit = ProductUnit(label: "items", quantityPerPackage: 1, gramsPerUnit: nil)

        state.restore(product: product(), unit: freshUnit, amount: 2)

        #expect(state.items.count == 1)
        #expect(state.items[0].unit.label == "items")
        #expect(state.unitConfigs[barcode]?.label == "items", "also establishes it as the remembered default, matching addProduct")
    }

    @Test("restore with a non-positive amount is a no-op")
    func restoreNonPositiveAmountIsNoOp() {
        let state = PantryStore()
        state.restore(product: product(), unit: unit(), amount: 0)
        #expect(state.items.isEmpty)
    }

    @Test("restore uses the barcode's remembered nutrition default when re-creating an item, not whatever nutrition the caller passed")
    func restoreUsesRememberedNutritionDefault() {
        let state = PantryStore()
        state.addProduct(product(nutrition: nutrition(calories: 250)), unit: unit(quantityPerPackage: 5))
        state.consume(barcode: barcode, amount: 5)

        state.restore(product: product(nutrition: nutrition(calories: 999)), unit: unit(), amount: 5)

        #expect(state.items[0].product.nutrition?.energyKcal100g == 250, "nutritionConfigs default wins over the passed-in product's nutrition")
    }
}
