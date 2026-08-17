import Foundation
import Testing
import FoodFoundation
@testable import MealKit

@Suite("Day/range nutrition aggregation")
struct AggregationTests {
    /// A weight-tracked ingredient: 150g at 250 kcal/100g -> 375 kcal.
    private func weightIngredient() -> LoggedIngredient {
        LoggedIngredient(
            barcode: "weight-tracked",
            productName: "Rice",
            productBrand: nil,
            imageURL: nil,
            amount: 150,
            unitLabel: "g",
            gramsResolved: 150,
            nutritionSnapshot: Fixture.nutrition(calories: 250).scaled(by: 150 / 100),
            usesFromPantry: true
        )
    }

    /// A count-tracked ingredient: 2 eggs at 50g/egg, 150 kcal/100g -> 150 kcal.
    private func countIngredient() -> LoggedIngredient {
        LoggedIngredient(
            barcode: "count-tracked",
            productName: "Egg",
            productBrand: nil,
            imageURL: nil,
            amount: 2,
            unitLabel: "eggs",
            gramsResolved: 100,
            nutritionSnapshot: Fixture.nutrition(calories: 150).scaled(by: 100 / 100),
            usesFromPantry: true
        )
    }

    private func missingNutritionIngredient() -> LoggedIngredient {
        LoggedIngredient(barcode: "no-data", productName: "Mystery Item", productBrand: nil, imageURL: nil, amount: 1, unitLabel: "items", gramsResolved: 0, nutritionSnapshot: nil, usesFromPantry: true)
    }

    @Test("dayTotal sums a mix of weight- and count-tracked ingredients into one complete total")
    func dayTotalSumsMixedTrackingModes() {
        let store = MealStore()
        store.logEaten(name: "Rice & Eggs", date: day(0), slot: .lunch, ingredients: [weightIngredient(), countIngredient()])

        let total = store.dayTotal(for: day(0))

        #expect(total.eaten.total.energyKcal100g == 525) // 375 + 150
        #expect(total.eaten.consideredCount == 2)
        #expect(total.eaten.missingCount == 0)
        #expect(total.eaten.isComplete)
    }

    @Test("a total reports incompleteness when an ingredient has no nutrition data, without hiding it in the sum")
    func totalReportsIncompleteness() {
        let store = MealStore()
        store.logEaten(name: "Mixed Meal", date: day(0), slot: .lunch, ingredients: [weightIngredient(), missingNutritionIngredient()])

        let total = store.dayTotal(for: day(0))

        #expect(total.eaten.total.energyKcal100g == 375, "only the ingredient with real data contributes")
        #expect(total.eaten.consideredCount == 2)
        #expect(total.eaten.missingCount == 1)
        #expect(!total.eaten.isComplete)
    }

    @Test("planned entries are excluded from the eaten total but included as a separate projection")
    func plannedExcludedFromEatenButProjectedSeparately() {
        let store = MealStore()
        store.logEaten(name: "Breakfast", date: day(0), slot: .breakfast, ingredients: [weightIngredient()])
        store.plan(name: "Dinner", date: day(0), slot: .dinner, ingredients: [countIngredient()])

        let total = store.dayTotal(for: day(0))

        #expect(total.eaten.total.energyKcal100g == 375, "the planned dinner must not be summed into eaten")
        #expect(total.eaten.consideredCount == 1)
        #expect(total.planned.total.energyKcal100g == 150, "but is available as its own projection")
        #expect(total.planned.consideredCount == 1)
    }

    @Test("dayTotal for a day with no entries at all is zero and complete, not missing")
    func dayTotalForEmptyDay() {
        let store = MealStore()
        let total = store.dayTotal(for: day(0))

        #expect(total.eaten.total.energyKcal100g == 0)
        #expect(total.eaten.consideredCount == 0)
        #expect(total.eaten.isComplete, "zero ingredients considered means nothing is missing")
    }

    @Test("dayTotal only considers entries on the requested calendar day")
    func dayTotalScopedToRequestedDay() {
        let store = MealStore()
        store.logEaten(name: "Today", date: day(0), slot: .lunch, ingredients: [weightIngredient()])
        store.logEaten(name: "Tomorrow", date: day(1), slot: .lunch, ingredients: [countIngredient()])

        let total = store.dayTotal(for: day(0))
        #expect(total.eaten.consideredCount == 1)
        #expect(total.eaten.total.energyKcal100g == 375)
    }

    @Test("rangeSummary produces one day per calendar day, including days with no entries")
    func rangeSummaryIncludesEmptyDays() {
        let store = MealStore()
        store.logEaten(name: "Day 0", date: day(0), slot: .lunch, ingredients: [weightIngredient()]) // 375 kcal
        // day(1) has nothing logged
        store.logEaten(name: "Day 2", date: day(2), slot: .lunch, ingredients: [countIngredient()]) // 150 kcal

        let summary = store.rangeSummary(from: day(0), to: day(2))

        #expect(summary.days.count == 3, "day 0, 1 (empty), and 2 must all be represented")
        #expect(summary.days[1].eaten.consideredCount == 0, "the empty middle day contributes zero, not being skipped")
        #expect(summary.averageEatenPerDay.energyKcal100g == 175) // (375 + 0 + 150) / 3
    }

    @Test("rangeSummary with a reversed range (start after end) yields no days")
    func rangeSummaryReversedRangeIsEmpty() {
        let store = MealStore()
        let summary = store.rangeSummary(from: day(2), to: day(0))
        #expect(summary.days.isEmpty)
        #expect(summary.averageEatenPerDay == .zero)
    }

    @Test("rangeSummary over a single day matches dayTotal for that day")
    func rangeSummarySingleDay() {
        let store = MealStore()
        store.logEaten(name: "Lunch", date: day(0), slot: .lunch, ingredients: [weightIngredient()])

        let summary = store.rangeSummary(from: day(0), to: day(0))
        #expect(summary.days.count == 1)
        #expect(summary.averageEatenPerDay.energyKcal100g == 375)
    }
}
