import Testing
@testable import FoodpointKit

@Suite("Nutrition")
struct NutritionTests {
    @Test("all-nil nutrition is effectively empty")
    func allNilIsEffectivelyEmpty() {
        let n = Nutrition(energyKcal100g: nil, proteins100g: nil, carbohydrates100g: nil, fat100g: nil, sugars100g: nil, fiber100g: nil, sodium100g: nil)
        #expect(n.isEffectivelyEmpty)
    }

    @Test("all-zero nutrition is effectively empty")
    func allZeroIsEffectivelyEmpty() {
        // The actual bug this guards against: some Open Food Facts entries
        // report a nutriments object with every field zero rather than
        // omitting it, which otherwise renders as real data.
        let n = Nutrition(energyKcal100g: 0, proteins100g: 0, carbohydrates100g: 0, fat100g: 0, sugars100g: 0, fiber100g: 0, sodium100g: 0)
        #expect(n.isEffectivelyEmpty)
    }

    @Test("any single non-zero field means not empty")
    func anyNonZeroFieldMeansNotEmpty() {
        let n = Nutrition(energyKcal100g: 0, proteins100g: 0, carbohydrates100g: 5.2, fat100g: 0, sugars100g: 0, fiber100g: 0, sodium100g: 0)
        #expect(!n.isEffectivelyEmpty)
    }

    @Test("approximate equality tolerates tiny float drift")
    func approximateEqualityTolerance() {
        let a = Nutrition(energyKcal100g: 250, proteins100g: 5.2, carbohydrates100g: 30, fat100g: 8, sugars100g: 3, fiber100g: 2, sodium100g: 0.5)
        let b = Nutrition(energyKcal100g: 250.001, proteins100g: 5.199, carbohydrates100g: 30, fat100g: 8, sugars100g: 3, fiber100g: 2, sodium100g: 0.5)
        #expect(a.isApproximatelyEqual(to: b))
    }

    @Test("a real difference in any field is not approximately equal")
    func realDifferenceIsNotEqual() {
        let a = Nutrition(energyKcal100g: 250, proteins100g: 5.2, carbohydrates100g: 30, fat100g: 8, sugars100g: 3, fiber100g: 2, sodium100g: 0.5)
        let b = Nutrition(energyKcal100g: 260, proteins100g: 5.2, carbohydrates100g: 30, fat100g: 8, sugars100g: 3, fiber100g: 2, sodium100g: 0.5)
        #expect(!a.isApproximatelyEqual(to: b))
    }

    @Test("nil versus a value is not approximately equal")
    func nilVersusValueIsNotEqual() {
        let a = Nutrition(energyKcal100g: nil, proteins100g: nil, carbohydrates100g: nil, fat100g: nil, sugars100g: nil, fiber100g: nil, sodium100g: nil)
        let b = Nutrition(energyKcal100g: 250, proteins100g: nil, carbohydrates100g: nil, fat100g: nil, sugars100g: nil, fiber100g: nil, sodium100g: nil)
        #expect(!a.isApproximatelyEqual(to: b))
    }

    @Test("scaled(by:) multiplies every field, preserving nils")
    func scaledMultipliesFields() {
        let perHundredGrams = Nutrition(energyKcal100g: 250, proteins100g: 10, carbohydrates100g: 20, fat100g: 8, sugars100g: nil, fiber100g: 2, sodium100g: 0.5)
        // A 40g bar: factor = 40 / 100 = 0.4
        let perBar = perHundredGrams.scaled(by: 0.4)
        #expect(perBar.energyKcal100g == 100)
        #expect(perBar.proteins100g == 4)
        #expect(perBar.carbohydrates100g == 8)
        #expect(perBar.fat100g == 3.2)
        #expect(perBar.sugars100g == nil)
        #expect(perBar.fiber100g == 0.8)
        #expect(perBar.sodium100g == 0.2)
    }
}
