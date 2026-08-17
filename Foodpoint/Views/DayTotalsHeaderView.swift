import SwiftUI
import FoodpointKit

/// A day's nutrition totals header (MK-6, meals-feature-design.md §8.1):
/// eaten calories/macros with an explicit completeness signal (§8.2), plus
/// planned calories as a separate "+X" projection whenever there are any
/// planned entries for the day — never summed into the eaten figure.
///
/// Built directly against `MealStore.dayTotal(for:)`'s existing `eaten`/
/// `planned` split (already present since MK-1) rather than any new
/// aggregation, so this degrades gracefully to "eaten only" today (no
/// `.planned` entries exist yet without a planning UI) and needs no rewrite
/// once MK-5's planning screens start creating `.planned` entries — the
/// projection line already reads live off whatever's there.
struct DayTotalsHeaderView: View {
    let date: Date

    @Environment(AppState.self) private var appState

    private var total: DayNutritionTotal {
        appState.meals.dayTotal(for: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summaryLine)
                .font(.subheadline)
                .bold()

            HStack {
                MetricView(label: "Calories", value: caloriesText)
                MetricView(label: "Protein", value: macroText(total.eaten.total.proteins100g))
                MetricView(label: "Carbs", value: macroText(total.eaten.total.carbohydrates100g))
                MetricView(label: "Fat", value: macroText(total.eaten.total.fat100g))
            }

            if !total.eaten.isComplete {
                Label(
                    "\(total.eaten.missingCount) of \(total.eaten.consideredCount) eaten ingredient\(total.eaten.consideredCount == 1 ? "" : "s") missing nutrition data",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    /// "eaten 1,240 kcal · planned +610" (meals-feature-design.md §8.1's own
    /// example wording) — the planned segment only appears when there's
    /// something planned for this day at all, so the common case (nothing
    /// planned yet) reads as a plain "eaten" line, not a confusing "+0".
    private var summaryLine: String {
        var line = "Eaten \(kcalText(total.eaten))"
        if total.planned.consideredCount > 0 {
            line += " · Planned +\(kcalText(total.planned))"
        }
        return line
    }

    private func kcalText(_ completeness: NutritionCompleteness) -> String {
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        return completeness.isComplete ? "\(kcal) kcal" : "≥ \(kcal) kcal"
    }

    /// Same "≥" honesty prefix as `MealCompositionEditorView`'s footer
    /// (meals-feature-design.md §8.2) — a partial total must never look
    /// exact.
    private var caloriesText: String {
        let kcal = (total.eaten.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        return total.eaten.isComplete ? "\(kcal) kcal" : "≥ \(kcal) kcal"
    }

    private func macroText(_ grams: Double?) -> String {
        "\((grams ?? 0).formatted(.number.precision(.fractionLength(0...1))))g"
    }
}
