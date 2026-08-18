import Foundation
import Testing
import FoodFoundation
@testable import MealKit

/// Covers `RangeNutritionSummary.caloricTrend` (MK-6, meals-feature-design.md
/// §8.1's "simple trend") — a plain description, never a judgment, since no
/// goals/targets exist yet (§11).
@Suite("Range caloric trend")
struct RangeTrendTests {
    /// A single-ingredient meal at exactly `calories` kcal (100g at
    /// `calories` kcal/100g, so the total equals `calories` directly).
    private func meal(calories: Double) -> LoggedIngredient {
        LoggedIngredient(
            barcode: "0001",
            productName: "Test",
            productBrand: nil,
            imageURL: nil,
            amount: 100,
            unitLabel: "g",
            gramsResolved: 100,
            nutritionSnapshot: Fixture.nutrition(calories: calories),
            usesFromPantry: true
        )
    }

    @Test("rising second-half average reports .increasing")
    func risingAverageIsIncreasing() {
        let store = MealStore()
        store.logEaten(name: "D0", date: day(0), slot: .lunch, ingredients: [meal(calories: 200)])
        store.logEaten(name: "D1", date: day(1), slot: .lunch, ingredients: [meal(calories: 200)])
        store.logEaten(name: "D2", date: day(2), slot: .lunch, ingredients: [meal(calories: 400)])
        store.logEaten(name: "D3", date: day(3), slot: .lunch, ingredients: [meal(calories: 400)])

        let summary = store.rangeSummary(from: day(0), to: day(3))
        #expect(summary.caloricTrend == .increasing)
    }

    @Test("falling second-half average reports .decreasing")
    func fallingAverageIsDecreasing() {
        let store = MealStore()
        store.logEaten(name: "D0", date: day(0), slot: .lunch, ingredients: [meal(calories: 400)])
        store.logEaten(name: "D1", date: day(1), slot: .lunch, ingredients: [meal(calories: 400)])
        store.logEaten(name: "D2", date: day(2), slot: .lunch, ingredients: [meal(calories: 200)])
        store.logEaten(name: "D3", date: day(3), slot: .lunch, ingredients: [meal(calories: 200)])

        let summary = store.rangeSummary(from: day(0), to: day(3))
        #expect(summary.caloricTrend == .decreasing)
    }

    @Test("a steady average across the range reports .flat")
    func steadyAverageIsFlat() {
        let store = MealStore()
        for offset in 0...3 {
            store.logEaten(name: "D\(offset)", date: day(offset), slot: .lunch, ingredients: [meal(calories: 300)])
        }

        let summary = store.rangeSummary(from: day(0), to: day(3))
        #expect(summary.caloricTrend == .flat)
    }

    @Test("a range under two days has nothing to compare and reports .flat")
    func singleDayRangeIsFlat() {
        let store = MealStore()
        store.logEaten(name: "D0", date: day(0), slot: .lunch, ingredients: [meal(calories: 900)])

        let summary = store.rangeSummary(from: day(0), to: day(0))
        #expect(summary.caloricTrend == .flat)
    }

    @Test("a tiny difference between halves stays .flat rather than reading as a trend")
    func smallDifferenceStaysFlat() {
        let store = MealStore()
        store.logEaten(name: "D0", date: day(0), slot: .lunch, ingredients: [meal(calories: 300)])
        store.logEaten(name: "D1", date: day(1), slot: .lunch, ingredients: [meal(calories: 306)]) // +2%

        let summary = store.rangeSummary(from: day(0), to: day(1))
        #expect(summary.caloricTrend == .flat)
    }

    @Test("an empty range with no entries at all is .flat, not an error")
    func emptyRangeIsFlat() {
        let store = MealStore()
        let summary = store.rangeSummary(from: day(0), to: day(3))
        #expect(summary.caloricTrend == .flat)
    }
}
