import Foundation
import Testing
@testable import MealKit

@Suite("MealSlot.current")
struct MealSlotTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func at(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 1, hour: hour))!
    }

    @Test("hour boundaries map to the expected slot")
    func hourBoundaries() {
        #expect(MealSlot.current(at: at(hour: 7), calendar: calendar) == .breakfast)
        #expect(MealSlot.current(at: at(hour: 10), calendar: calendar) == .breakfast)
        #expect(MealSlot.current(at: at(hour: 11), calendar: calendar) == .lunch)
        #expect(MealSlot.current(at: at(hour: 14), calendar: calendar) == .lunch)
        #expect(MealSlot.current(at: at(hour: 15), calendar: calendar) == .dinner)
        #expect(MealSlot.current(at: at(hour: 20), calendar: calendar) == .dinner)
        #expect(MealSlot.current(at: at(hour: 21), calendar: calendar) == .snack)
        #expect(MealSlot.current(at: at(hour: 23), calendar: calendar) == .snack)
    }
}
