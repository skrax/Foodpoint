import Foundation
import Testing
import FoodFoundation
@testable import MealKit

@Suite("Template instantiation — fresh nutrition every time")
struct TemplateInstantiationTests {
    @Test("instantiate re-resolves nutrition fresh rather than reusing a stale cached value")
    func instantiateReResolvesFresh() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001", nutrition: Fixture.nutrition(calories: 200))])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let template = MealTemplate(
            name: "Morning Toast",
            defaultSlot: .breakfast,
            ingredients: [TemplateIngredient(barcode: "0001", productName: "Bread", productBrand: nil, imageURL: nil, amount: 2, unit: Fixture.countUnit(gramsPerUnit: 50))]
        )

        let firstPass = try await store.instantiate(template)
        #expect(firstPass[0].nutritionSnapshot?.energyKcal100g == 200)
        #expect(await stub.callCount == 1)

        // The product's nutrition changed on Open Food Facts since the last
        // instantiation (e.g. the user corrected it) — a second
        // instantiation must reflect that, not the value cached the first
        // time around.
        await stub.set(Fixture.product(barcode: "0001", nutrition: Fixture.nutrition(calories: 999)), forBarcode: "0001")

        let secondPass = try await store.instantiate(template)
        #expect(secondPass[0].nutritionSnapshot?.energyKcal100g == 999)
        #expect(await stub.callCount == 2, "instantiation must call the resolver again, not reuse the first pass's result")
    }

    @Test("instantiate resolves every ingredient, one resolver call each")
    func instantiateResolvesEveryIngredient() async throws {
        let stub = StubProductResolver(products: [
            "0001": Fixture.product(barcode: "0001", name: "Bread"),
            "0002": Fixture.product(barcode: "0002", name: "Egg"),
        ])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let template = MealTemplate(
            name: "Morning Toast",
            defaultSlot: .breakfast,
            ingredients: [
                TemplateIngredient(barcode: "0001", productName: "Bread", productBrand: nil, imageURL: nil, amount: 2, unit: Fixture.countUnit(gramsPerUnit: 50)),
                TemplateIngredient(barcode: "0002", productName: "Egg", productBrand: nil, imageURL: nil, amount: 1, unit: Fixture.countUnit(label: "eggs", gramsPerUnit: 50)),
            ]
        )

        let ingredients = try await store.instantiate(template)
        #expect(ingredients.count == 2)
        #expect(ingredients.map(\.productName) == ["Bread", "Egg"])
        #expect(await stub.callCount == 2)
    }

    @Test("usesFromPantry seeds from the template ingredient's default")
    func usesFromPantrySeedsFromTemplateDefault() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001")])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let template = MealTemplate(
            name: "Café Order",
            defaultSlot: .lunch,
            ingredients: [TemplateIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, amount: 1, unit: Fixture.countUnit(), usesFromPantry: false)]
        )

        let ingredients = try await store.instantiate(template)
        #expect(ingredients[0].usesFromPantry == false)
    }

    @Test("usesFromPantry is independently editable per logged instance after seeding, without affecting the template")
    func usesFromPantryIndependentPerInstance() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001")])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let template = MealTemplate(
            name: "Morning Eggs",
            defaultSlot: .breakfast,
            ingredients: [TemplateIngredient(barcode: "0001", productName: nil, productBrand: nil, imageURL: nil, amount: 2, unit: Fixture.countUnit(label: "eggs"), usesFromPantry: true)]
        )
        store.addTemplate(template)

        var ingredients = try await store.instantiate(template)
        #expect(ingredients[0].usesFromPantry == true, "seeded from the template's default")

        // Editing this logged instance's flag (e.g. "actually, this was a
        // café order this time") must not reach back and mutate the
        // template's own default.
        ingredients[0].usesFromPantry = false
        let entry = store.logEaten(name: template.name, date: Date(), slot: .breakfast, ingredients: ingredients, templateID: template.id)

        #expect(entry.ingredients[0].usesFromPantry == false)
        #expect(store.templates[0].ingredients[0].usesFromPantry == true, "template default is untouched")

        // Instantiating again confirms the template still seeds `true`.
        let againIngredients = try await store.instantiate(store.templates[0])
        #expect(againIngredients[0].usesFromPantry == true)
    }
}
