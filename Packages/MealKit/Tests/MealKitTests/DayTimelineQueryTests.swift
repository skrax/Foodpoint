import Foundation
import Testing
import FoodFoundation
@testable import MealKit

/// Covers the pure query/comparison logic added for the day timeline (MK-5,
/// meals-feature-design.md §10) — `entries(on:)`/`entriesGroupedBySlot(on:)`
/// and `stockShortfalls(for:availableQuantity:)`. None of this touches
/// `PantryKit` (it isn't even a dependency of this test target); the
/// stock-shortfall check takes availability as a closure specifically so it
/// can be exercised here without any pantry state at all.
@Suite("Day timeline queries and stock-shortfall signal")
struct DayTimelineQueryTests {
    private func ingredient(
        barcode: String = "0001",
        productName: String = "Egg",
        amount: Double = 6,
        unitLabel: String = "eggs",
        usesFromPantry: Bool = true
    ) -> LoggedIngredient {
        LoggedIngredient(
            barcode: barcode,
            productName: productName,
            productBrand: nil,
            imageURL: nil,
            amount: amount,
            unitLabel: unitLabel,
            gramsResolved: amount * 50,
            nutritionSnapshot: Fixture.nutrition(),
            usesFromPantry: usesFromPantry
        )
    }

    // MARK: - entries(on:)

    @Test("entries(on:) returns only entries on the requested calendar day, planned and eaten alike")
    func entriesOnDayIncludesBothStatuses() {
        let store = MealStore()
        let eaten = store.logEaten(name: "Breakfast", date: day(0), slot: .breakfast, ingredients: [ingredient()])
        let planned = store.plan(name: "Dinner", date: day(0), slot: .dinner, ingredients: [ingredient()])
        store.logEaten(name: "Tomorrow", date: day(1), slot: .breakfast, ingredients: [ingredient()])

        let today = store.entries(on: day(0))

        #expect(today.count == 2)
        #expect(Set(today.map(\.id)) == Set([eaten.id, planned.id]))
    }

    @Test("entries(on:) for a day with nothing logged is empty")
    func entriesOnEmptyDay() {
        let store = MealStore()
        #expect(store.entries(on: day(0)).isEmpty)
    }

    // MARK: - entriesGroupedBySlot(on:)

    @Test("entriesGroupedBySlot includes every MealSlot in a fixed order, even when empty")
    func groupedBySlotIncludesEverySlot() {
        let store = MealStore()
        store.logEaten(name: "Toast", date: day(0), slot: .breakfast, ingredients: [ingredient()])

        let grouped = store.entriesGroupedBySlot(on: day(0))

        #expect(grouped.map(\.slot) == [.breakfast, .lunch, .dinner, .snack])
        #expect(grouped[0].entries.count == 1)
        #expect(grouped[1].entries.isEmpty)
        #expect(grouped[2].entries.isEmpty)
        #expect(grouped[3].entries.isEmpty)
    }

    @Test("entriesGroupedBySlot puts each entry in its own slot's bucket, not just chronological order")
    func groupedBySlotBucketsCorrectly() {
        let store = MealStore()
        store.logEaten(name: "Dinner", date: day(0), slot: .dinner, ingredients: [ingredient()])
        store.logEaten(name: "Breakfast", date: day(0), slot: .breakfast, ingredients: [ingredient()])

        let grouped = store.entriesGroupedBySlot(on: day(0))

        #expect(grouped.first(where: { $0.slot == .breakfast })?.entries.first?.name == "Breakfast")
        #expect(grouped.first(where: { $0.slot == .dinner })?.entries.first?.name == "Dinner")
    }

    // MARK: - stockShortfalls

    @Test("stockShortfalls flags an ingredient that needs more than what's available")
    func flagsInsufficientStock() {
        let shortfalls = MealStore.stockShortfalls(for: [ingredient(amount: 6)]) { _ in 4 }

        #expect(shortfalls.count == 1)
        #expect(shortfalls[0].productName == "Egg")
        #expect(shortfalls[0].needed == 6)
        #expect(shortfalls[0].available == 4)
    }

    @Test("stockShortfalls is empty when the pantry has enough")
    func emptyWhenStockSufficient() {
        let shortfalls = MealStore.stockShortfalls(for: [ingredient(amount: 4)]) { _ in 6 }
        #expect(shortfalls.isEmpty)
    }

    @Test("stockShortfalls is empty when needed exactly equals available")
    func emptyWhenExactlyEnough() {
        let shortfalls = MealStore.stockShortfalls(for: [ingredient(amount: 4)]) { _ in 4 }
        #expect(shortfalls.isEmpty)
    }

    @Test("an unknown barcode (nil availability) is treated as zero available")
    func unknownBarcodeTreatedAsZero() {
        let shortfalls = MealStore.stockShortfalls(for: [ingredient(amount: 1)]) { _ in nil }
        #expect(shortfalls.count == 1)
        #expect(shortfalls[0].available == 0)
    }

    @Test("ingredients with usesFromPantry off are never flagged, regardless of stock")
    func togglOffIngredientsNeverFlagged() {
        let shortfalls = MealStore.stockShortfalls(for: [ingredient(amount: 100, usesFromPantry: false)]) { _ in 0 }
        #expect(shortfalls.isEmpty)
    }

    @Test("stockShortfalls never mutates the availability source — it's a pure read")
    func doesNotMutateAvailability() {
        var callCount = 0
        _ = MealStore.stockShortfalls(for: [ingredient(amount: 6), ingredient(barcode: "0002", amount: 2)]) { _ in
            callCount += 1
            return 10
        }
        #expect(callCount == 2, "one read per ingredient, nothing more")
    }
}
