import SwiftUI
import FoodpointKit

/// Week/month nutrition range summary (MK-6, meals-feature-design.md §8.1):
/// one row per calendar day plus an average and a simple trend, built
/// entirely on `MealStore.rangeSummary(from:to:)`/`.caloricTrend` — pure
/// aggregation that already existed (or, for the trend, was added alongside
/// this view) in `MealKit`, so this view itself does no math beyond
/// formatting. Deliberately *description*, not *evaluation* — no goals or
/// targets are shown or implied (meals-feature-design.md §11's deferral).
struct RangeSummaryView: View {
    @Environment(AppState.self) private var appState
    @State private var rangeKind: RangeKind = .week

    /// How far back the summary looks, ending today. A plain, fixed choice
    /// (last 7 vs. last 30 calendar days) rather than calendar-aligned
    /// week/month boundaries — simplest thing that satisfies "week/month
    /// range summary" (design doc §8.1) without adding date-picker UI this
    /// task doesn't ask for.
    private enum RangeKind: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        var id: String { rawValue }
        /// Number of calendar days *before* today to reach back — 6 for a
        /// 7-day week, 29 for a 30-day month, both inclusive of today.
        var daysBack: Int { self == .week ? 6 : 29 }
    }

    private var calendar: Calendar { .current }

    private var range: (start: Date, end: Date) {
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -rangeKind.daysBack, to: end) ?? end
        return (start, end)
    }

    private var summary: RangeNutritionSummary {
        appState.meals.rangeSummary(from: range.start, to: range.end, calendar: calendar)
    }

    var body: some View {
        List {
            Section {
                Picker("Range", selection: $rangeKind) {
                    ForEach(RangeKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            }

            Section("Average Per Day") {
                HStack {
                    MetricView(label: "Calories", value: "\(Int(summary.averageEatenPerDay.energyKcal100g ?? 0)) kcal")
                    MetricView(label: "Protein", value: macroText(summary.averageEatenPerDay.proteins100g))
                    MetricView(label: "Carbs", value: macroText(summary.averageEatenPerDay.carbohydrates100g))
                    MetricView(label: "Fat", value: macroText(summary.averageEatenPerDay.fat100g))
                }
            }

            Section("Trend") {
                Label(trendText, systemImage: trendIcon)
                    .foregroundStyle(trendColor)
            }

            Section("Daily Totals") {
                ForEach(summary.days, id: \.date) { day in
                    dayRow(day)
                }
            }
        }
        .navigationTitle("Range Summary")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func dayRow(_ day: DayNutritionTotal) -> some View {
        HStack {
            Text(day.date, format: .dateTime.month(.abbreviated).day().weekday(.abbreviated))
            Spacer()
            if day.eaten.consideredCount == 0 {
                Text("No entries")
                    .foregroundStyle(.secondary)
            } else {
                Text(kcalText(day.eaten))
                    .foregroundStyle(day.eaten.isComplete ? Color.primary : Color.orange)
            }
        }
        .font(.subheadline)
    }

    private func kcalText(_ completeness: NutritionCompleteness) -> String {
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        return completeness.isComplete ? "\(kcal) kcal" : "≥ \(kcal) kcal"
    }

    private func macroText(_ grams: Double?) -> String {
        "\((grams ?? 0).formatted(.number.precision(.fractionLength(0...1))))g"
    }

    /// Plain descriptive wording, on purpose — no "good"/"bad" framing,
    /// since there's nothing to evaluate against (§11).
    private var trendText: String {
        switch summary.caloricTrend {
        case .increasing: return "Trending up across this range"
        case .decreasing: return "Trending down across this range"
        case .flat: return "Roughly flat across this range"
        }
    }

    private var trendIcon: String {
        switch summary.caloricTrend {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch summary.caloricTrend {
        case .increasing, .decreasing: return .primary
        case .flat: return .secondary
        }
    }
}
