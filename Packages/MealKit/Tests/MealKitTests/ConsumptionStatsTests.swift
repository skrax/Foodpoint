import Foundation
import Testing
import FoodFoundation
@testable import MealKit

@Suite("Consumption stats")
struct ConsumptionStatsTests {
    private func ingredient(barcode: String, usesFromPantry: Bool = true) -> LoggedIngredient {
        LoggedIngredient(barcode: barcode, productName: "Bread", productBrand: nil, imageURL: nil, amount: 2, unitLabel: "slices", gramsResolved: 100, nutritionSnapshot: Fixture.nutrition(), usesFromPantry: usesFromPantry)
    }

    @Test("consumption rate divides by the full requested range, including days with no entries")
    func consumptionRateIncludesEmptyDays() {
        let store = MealStore()
        // Eaten on day 0 and day 4 only, across a 5-day range (days 0...4).
        store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [ingredient(barcode: "0001")])
        store.logEaten(name: "Toast", date: day(4), slot: .breakfast, ingredients: [ingredient(barcode: "0001")])

        let stats = store.consumptionStats(barcode: "0001", from: day(0), to: day(4))

        #expect(stats.timesEaten == 2)
        #expect(stats.consumptionRatePerDay == 2.0 / 5.0, "2 times over 5 calendar days, not 2 over the 2 active days")
    }

    @Test("consumption stats for a barcode never eaten in the range is zero, not an error")
    func neverEatenIsZeroNotError() {
        let store = MealStore()
        let stats = store.consumptionStats(barcode: "0001", from: day(0), to: day(6))

        #expect(stats.timesEaten == 0)
        #expect(stats.totalAmount == 0)
        #expect(stats.lastEatenDate == nil)
        #expect(stats.consumptionRatePerDay == 0)
    }

    @Test("consumption stats count every matching ingredient row regardless of usesFromPantry")
    func countsRegardlessOfUsesFromPantry() {
        let store = MealStore()
        store.logEaten(name: "Own eggs", date: day(0), slot: .breakfast, ingredients: [ingredient(barcode: "0001", usesFromPantry: true)])
        store.logEaten(name: "Café order", date: day(1), slot: .lunch, ingredients: [ingredient(barcode: "0001", usesFromPantry: false)])

        let stats = store.consumptionStats(barcode: "0001", from: day(0), to: day(1))
        #expect(stats.timesEaten == 2, "\"did I eat this\" counts regardless of where it came from (design doc §9)")
    }

    @Test("planned (not yet eaten) entries don't count toward consumption")
    func plannedEntriesExcludedFromConsumption() {
        let store = MealStore()
        store.plan(name: "Toast", date: day(0), slot: .breakfast, ingredients: [ingredient(barcode: "0001")])

        let stats = store.consumptionStats(barcode: "0001", from: day(0), to: day(0))
        #expect(stats.timesEaten == 0)
    }

    @Test("totalAmount and lastEatenDate accumulate across matching entries")
    func totalAmountAndLastEatenDate() {
        let store = MealStore()
        store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [ingredient(barcode: "0001")]) // amount 2
        store.logEaten(name: "Toast", date: day(3), slot: .breakfast, ingredients: [ingredient(barcode: "0001")]) // amount 2

        let stats = store.consumptionStats(barcode: "0001", from: day(0), to: day(5))
        #expect(stats.totalAmount == 4)
        #expect(stats.lastEatenDate.map { day3 in Calendar.current.isDate(day3, inSameDayAs: day(3)) } == true)
    }

    @Test("mostConsumed ranks barcodes by times eaten, most first")
    func mostConsumedRanksByTimesEaten() {
        let store = MealStore()
        store.logEaten(name: "Bread x1", date: day(0), slot: .breakfast, ingredients: [ingredient(barcode: "bread")])
        store.logEaten(name: "Egg x1", date: day(0), slot: .breakfast, ingredients: [ingredient(barcode: "egg")])
        store.logEaten(name: "Egg x2", date: day(1), slot: .breakfast, ingredients: [ingredient(barcode: "egg")])

        let ranked = store.mostConsumed(from: day(0), to: day(1))
        #expect(ranked.first?.barcode == "egg")
        #expect(ranked.first?.timesEaten == 2)
    }
}
