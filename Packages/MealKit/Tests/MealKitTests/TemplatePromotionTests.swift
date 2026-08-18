import Foundation
import Testing
import FoodFoundation
@testable import MealKit

/// Covers the pure, network-free logic MK-4 adds on top of MK-1's template
/// scaffolding and MK-3's `instantiate`: promoting an already-resolved
/// `LoggedIngredient` back into a `TemplateIngredient`
/// (`TemplateIngredient.init(logged:)` — the conversion behind both the
/// "New Meal" editor and "Remember this meal?", meals-feature-design.md §7)
/// and the one-tap `logTemplate`/`planTemplate` instantiate-and-log
/// semantics (already partially covered by `TemplateInstantiationTests`'
/// `instantiate` tests, but not the `logEaten`/`plan` wiring on top).
@Suite("Template promotion and one-tap logging (MK-4)")
struct TemplatePromotionTests {
    // MARK: - TemplateIngredient(logged:)

    @Test("TemplateIngredient(logged:) carries over identity fields and reconstructs unit via impliedUnit")
    func templateIngredientFromLoggedCarriesFields() {
        let logged = MealStore.makeIngredient(
            barcode: "0001",
            productName: "Bread",
            productBrand: "Acme",
            imageURL: URL(string: "https://example.com/bread.jpg"),
            nutritionPer100g: Fixture.nutrition(calories: 200),
            amount: 2,
            unit: Fixture.countUnit(label: "slices", gramsPerUnit: 50),
            usesFromPantry: false
        )

        let templateIngredient = TemplateIngredient(logged: logged)

        #expect(templateIngredient.barcode == "0001")
        #expect(templateIngredient.productName == "Bread")
        #expect(templateIngredient.productBrand == "Acme")
        #expect(templateIngredient.imageURL == logged.imageURL)
        #expect(templateIngredient.amount == 2)
        #expect(templateIngredient.unit.label == "slices")
        #expect(templateIngredient.unit.gramsPerUnit == 50) // reconstructed: 100g resolved / 2 = 50g/slice
        #expect(templateIngredient.usesFromPantry == false, "carries the logged instance's own toggle, not a hardcoded default")
    }

    @Test("TemplateIngredient(logged:) gets its own fresh id, independent of the logged ingredient's id")
    func templateIngredientFromLoggedHasFreshID() {
        let logged = MealStore.makeIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, nutritionPer100g: nil, amount: 1, unit: Fixture.weightUnit())
        let templateIngredient = TemplateIngredient(logged: logged)
        #expect(templateIngredient.id != logged.id)
    }

    // MARK: - logTemplate: one-tap instantiate-and-log

    @Test("logTemplate instantiates fresh and immediately logs the entry as eaten")
    func logTemplateCreatesEatenEntry() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001", name: "Bread", nutrition: Fixture.nutrition(calories: 200))])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })
        let template = MealTemplate(
            name: "Morning Toast",
            defaultSlot: .breakfast,
            ingredients: [TemplateIngredient(barcode: "0001", productName: "Bread", productBrand: nil, imageURL: nil, amount: 2, unit: Fixture.countUnit(gramsPerUnit: 50))]
        )

        let entry = try await store.logTemplate(template, date: day(0))

        #expect(entry.status == .eaten)
        #expect(entry.name == "Morning Toast")
        #expect(entry.templateID == template.id)
        #expect(entry.slot == .breakfast, "defaults to the template's own defaultSlot when none is given")
        #expect(entry.ingredients.count == 1)
        #expect(entry.ingredients[0].nutritionSnapshot?.energyKcal100g == 200)
        #expect(store.entries.contains(where: { $0.id == entry.id }))
    }

    @Test("logTemplate honors an explicit slot override instead of the template's default")
    func logTemplateHonorsSlotOverride() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001")])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })
        let template = MealTemplate(
            name: "Café Order",
            defaultSlot: .breakfast,
            ingredients: [TemplateIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, amount: 1, unit: Fixture.countUnit())]
        )

        let entry = try await store.logTemplate(template, date: day(0), slot: .snack)

        #expect(entry.slot == .snack)
    }

    @Test("planTemplate schedules a planned entry instead of an eaten one")
    func planTemplateCreatesPlannedEntry() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001")])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })
        let template = MealTemplate(
            name: "Rice Bowl",
            defaultSlot: .lunch,
            ingredients: [TemplateIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, amount: 150, unit: Fixture.weightUnit())]
        )

        let entry = try await store.planTemplate(template, date: day(1))

        #expect(entry.status == .planned)
        #expect(entry.templateID == template.id)
    }

    @Test("logTemplate re-resolves nutrition fresh each call, same as instantiate")
    func logTemplateReResolvesFreshEachCall() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001", nutrition: Fixture.nutrition(calories: 200))])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })
        let template = MealTemplate(
            name: "Morning Toast",
            defaultSlot: .breakfast,
            // amount 2 * 50g/unit = 100g, so the per-100g fixture value
            // comes through unscaled — keeps the math in this test trivial.
            ingredients: [TemplateIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, amount: 2, unit: Fixture.countUnit(gramsPerUnit: 50))]
        )

        let first = try await store.logTemplate(template, date: day(0))
        #expect(first.ingredients[0].nutritionSnapshot?.energyKcal100g == 200)

        await stub.set(Fixture.product(barcode: "0001", nutrition: Fixture.nutrition(calories: 999)), forBarcode: "0001")

        let second = try await store.logTemplate(template, date: day(1))
        #expect(second.ingredients[0].nutritionSnapshot?.energyKcal100g == 999, "one-tap logging is a live recipe, not a cached one")
    }
}
