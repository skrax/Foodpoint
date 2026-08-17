import Foundation
import Testing
import FoodFoundation
@testable import MealKit

@Suite("Ingredient resolution — immediate snapshot")
struct IngredientResolutionTests {
    @Test("resolveIngredient snapshots product identity and nutrition immediately, in one resolver call")
    func resolveIngredientSnapshotsImmediately() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001", name: "Bread", brand: "Acme", nutrition: Fixture.nutrition(calories: 200))])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let ingredient = try await store.resolveIngredient(barcode: "0001", amount: 2, unit: Fixture.countUnit(gramsPerUnit: 50))

        #expect(ingredient.barcode == "0001")
        #expect(ingredient.productName == "Bread")
        #expect(ingredient.productBrand == "Acme")
        #expect(ingredient.unitLabel == "slices")
        #expect(ingredient.gramsResolved == 100) // 2 slices * 50g
        #expect(ingredient.nutritionSnapshot?.energyKcal100g == 200) // 200 kcal/100g * (100g/100)
        #expect(await stub.callCount == 1)
    }

    @Test("browsing an already-resolved ingredient's cached fields makes no further resolver call")
    func alreadyAddedIngredientNeedsNoNetworkCall() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001")])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let ingredient = try await store.resolveIngredient(barcode: "0001", amount: 1, unit: Fixture.countUnit())
        #expect(await stub.callCount == 1)

        // "Browsing history" is just reading the already-snapshotted fields —
        // no MealStore/FoodFoundation call is involved at all.
        _ = ingredient.productName
        _ = ingredient.productBrand
        _ = ingredient.imageURL
        _ = ingredient.nutritionSnapshot
        #expect(await stub.callCount == 1, "reading cached fields must not trigger another resolution")
    }

    @Test("resolveTemplateIngredient snapshots identity but deliberately carries no nutrition")
    func resolveTemplateIngredientCarriesNoNutrition() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001", name: "Bread", nutrition: Fixture.nutrition())])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let ingredient = try await store.resolveTemplateIngredient(barcode: "0001", amount: 2, unit: Fixture.countUnit())

        #expect(ingredient.productName == "Bread")
        // TemplateIngredient has no nutrition field at all (design doc §4.1) —
        // this just confirms the identity snapshot happened; there is no
        // nutrition property to assert is absent.
        #expect(ingredient.amount == 2)
        #expect(ingredient.usesFromPantry == true, "defaults on per meals-feature-design.md §4.4/§12 #6")
    }

    @Test("an all-zero (effectively empty) Open Food Facts nutriments object resolves to a nil snapshot, not zeroes")
    func effectivelyEmptyNutritionResolvesToNil() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001", nutrition: Fixture.emptyNutrition())])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let ingredient = try await store.resolveIngredient(barcode: "0001", amount: 1, unit: Fixture.countUnit())
        #expect(ingredient.nutritionSnapshot == nil)
    }

    @Test("a product with no nutrition at all resolves to a nil snapshot")
    func missingNutritionResolvesToNil() async throws {
        let stub = StubProductResolver(products: ["0001": Fixture.product(barcode: "0001", nutrition: nil)])
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        let ingredient = try await store.resolveIngredient(barcode: "0001", amount: 1, unit: Fixture.countUnit())
        #expect(ingredient.nutritionSnapshot == nil)
    }

    @Test("an unresolvable barcode throws rather than producing a partial ingredient")
    func unknownBarcodeThrows() async throws {
        let stub = StubProductResolver()
        let store = MealStore(productResolver: { barcode in try await stub.resolve(barcode) })

        await #expect(throws: StubProductResolver.ResolutionError.self) {
            _ = try await store.resolveIngredient(barcode: "unknown", amount: 1, unit: Fixture.countUnit())
        }
    }
}
