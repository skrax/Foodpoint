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

    /// A simple, *description*-only direction for eaten calories across this
    /// range — the "simple trend" meals-feature-design.md §8.1 asks for,
    /// deliberately not an evaluation against any goal (no goals/targets
    /// exist yet, §11's deferral). Compares the mean eaten `energyKcal100g`
    /// across the first half of `days` against the second half; `.flat` for
    /// fewer than two days (nothing to compare), or when the two halves
    /// differ by less than 5% — small day-to-day noise shouldn't read as a
    /// trend.
    public var caloricTrend: NutritionTrend {
        guard days.count >= 2 else { return .flat }
        let midpoint = days.count / 2
        let firstHalf = days[..<midpoint]
        let secondHalf = days[midpoint...]
        let firstAverage = firstHalf.reduce(0.0) { $0 + ($1.eaten.total.energyKcal100g ?? 0) } / Double(firstHalf.count)
        let secondAverage = secondHalf.reduce(0.0) { $0 + ($1.eaten.total.energyKcal100g ?? 0) } / Double(secondHalf.count)
        guard firstAverage > 0 else { return secondAverage > 0 ? .increasing : .flat }
        let relativeChange = (secondAverage - firstAverage) / firstAverage
        if relativeChange > 0.05 { return .increasing }
        if relativeChange < -0.05 { return .decreasing }
        return .flat
    }
}

/// `RangeNutritionSummary.caloricTrend`'s result — a plain direction, not a
/// judgment. Deliberately has no "good"/"bad" framing: this feature
/// describes eating patterns, it doesn't evaluate them against a goal
/// (meals-feature-design.md §11 defers goals/targets entirely).
public enum NutritionTrend: Equatable {
    /// The second half of the range averaged meaningfully more eaten
    /// calories per day than the first half.
    case increasing
    /// The second half averaged meaningfully less.
    case decreasing
    /// No meaningful difference between the two halves (or too few days to
    /// compare at all).
    case flat
}

/// How a set of logged ingredients' nutrition data is provenanced — Open
/// Food Facts vs. a user's own "Custom" entries
/// (`FoodFoundation.NutritionSource`, already badged this way throughout the
/// app) — so a meal built mostly on hand-entered numbers is distinguishable
/// from one built on Open Food Facts data (meals-feature-design.md §8.3).
/// Produced by `MealStore.provenanceMix(for:)`.
public struct NutritionProvenanceMix: Equatable {
    /// Ingredients with real nutrition data sourced from Open Food Facts.
    public var openFoodFactsCount: Int
    /// Ingredients with real nutrition data the user entered by hand.
    public var customCount: Int
    /// Ingredients with real nutrition data whose source wasn't recorded —
    /// e.g. logged before `LoggedIngredient.nutritionSource` existed.
    /// Surfaced separately rather than folded into either count above, so
    /// the mix never claims more certainty about provenance than it has.
    public var unknownCount: Int
    /// Ingredients with no nutrition data at all. Provenance is moot for
    /// these — `NutritionCompleteness.missingCount` already reports this
    /// gap; this field exists so `openFoodFactsCount + customCount +
    /// unknownCount + noDataCount` always accounts for every ingredient
    /// considered.
    public var noDataCount: Int

    public init(openFoodFactsCount: Int, customCount: Int, unknownCount: Int, noDataCount: Int) {
        self.openFoodFactsCount = openFoodFactsCount
        self.customCount = customCount
        self.unknownCount = unknownCount
        self.noDataCount = noDataCount
    }

    /// Ingredients with real nutrition data and a known source — the
    /// denominator for describing the provenance mix (e.g. "3 of 4 from
    /// Open Food Facts").
    public var consideredCount: Int { openFoodFactsCount + customCount }
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
