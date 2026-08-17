import Foundation
import FoodFoundation

/// A summed nutrition total together with how much of the underlying
/// ingredient set actually had usable nutrition data.
///
/// The app already refuses to display Open Food Facts' all-zero nutriments
/// as if they were real data (`Nutrition.isEffectivelyEmpty`); aggregation
/// must extend that same honesty principle, because summing hides the gap —
/// a meal where two of five ingredients have no nutrition data would
/// otherwise total to a confident-looking number that is simply wrong, with
/// no visual cue anything is missing (meals-feature-design.md §8.2). Every
/// total this package produces carries its completeness alongside it; never
/// display `total` without also surfacing `missingCount`.
public struct NutritionCompleteness: Equatable {
    /// Sum of every ingredient's `nutritionSnapshot` that had one. Missing
    /// ingredients contribute nothing here — they're counted in
    /// `missingCount` instead of silently treated as zero.
    public var total: Nutrition
    /// How many ingredients this total was built from, whether or not each
    /// one had usable nutrition data.
    public var consideredCount: Int
    /// How many of `consideredCount` had no usable nutrition data
    /// (`nutritionSnapshot == nil`).
    public var missingCount: Int

    public init(total: Nutrition, consideredCount: Int, missingCount: Int) {
        self.total = total
        self.consideredCount = consideredCount
        self.missingCount = missingCount
    }

    /// `true` when every considered ingredient contributed real nutrition
    /// data — `total` can be trusted as exact rather than a lower bound.
    public var isComplete: Bool { missingCount == 0 }
}

/// A single day's nutrition picture: what was actually eaten, and what's
/// planned as a separate projection. Planned and eaten must never be
/// silently summed into one number — "what I've eaten" and "what I intend
/// to eat" are different claims (meals-feature-design.md §8.1).
public struct DayNutritionTotal: Equatable {
    public var date: Date
    /// Total across every `.eaten` entry's ingredients for this day.
    public var eaten: NutritionCompleteness
    /// Total across every `.planned` entry's ingredients for this day — a
    /// separate projection, e.g. "eaten 1,240 kcal · planned +610", never
    /// folded into `eaten`.
    public var planned: NutritionCompleteness

    public init(date: Date, eaten: NutritionCompleteness, planned: NutritionCompleteness) {
        self.date = date
        self.eaten = eaten
        self.planned = planned
    }
}

/// A week/month view: one `DayNutritionTotal` per day in the range —
/// including days with no entries at all, so an average is a true
/// per-calendar-day figure rather than an average-of-active-days — plus the
/// average eaten total per day (meals-feature-design.md §8.1). Kept to
/// description rather than evaluation on purpose: no goals/targets exist
/// yet (design doc §11).
public struct RangeNutritionSummary: Equatable {
    public var days: [DayNutritionTotal]
    public var averageEatenPerDay: Nutrition

    public init(days: [DayNutritionTotal], averageEatenPerDay: Nutrition) {
        self.days = days
        self.averageEatenPerDay = averageEatenPerDay
    }
}

/// How often and how much of one product has been eaten over a date range —
/// falls out of the log for free, since every `.eaten` entry's ingredient
/// rows already are the consumption record, regardless of `usesFromPantry`
/// ("did I eat this" and "did it come out of my shelf" are different
/// questions — meals-feature-design.md §9).
public struct ConsumptionStats: Equatable {
    public var barcode: String
    /// Number of ingredient rows for this barcode across `.eaten` entries
    /// in the queried range.
    public var timesEaten: Int
    /// Sum of `amount` across those rows (in whatever unit each row was
    /// logged in — not grams-normalized, since different logged instances
    /// of the same barcode could in principle use different units).
    public var totalAmount: Double
    /// The most recent date this barcode was eaten in the range, or `nil`
    /// if never.
    public var lastEatenDate: Date?
    /// `timesEaten` divided by the number of calendar days in the queried
    /// range — including days with no entries — so a short burst of
    /// logging doesn't read as a higher rate than it is. This is the
    /// undecorated signal a future restock prompt ("you eat this weekly and
    /// have 1 left") would be built from; that prompt itself is deferred
    /// (design doc §9, §11), but the data supports it.
    public var consumptionRatePerDay: Double

    public init(barcode: String, timesEaten: Int, totalAmount: Double, lastEatenDate: Date?, consumptionRatePerDay: Double) {
        self.barcode = barcode
        self.timesEaten = timesEaten
        self.totalAmount = totalAmount
        self.lastEatenDate = lastEatenDate
        self.consumptionRatePerDay = consumptionRatePerDay
    }
}
