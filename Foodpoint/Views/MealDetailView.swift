import SwiftUI
import FoodpointKit

/// Detail screen for one `MealEntry` (MK-6): its ingredient rows, a nutrition
/// completeness total (§8.2, same signal `MealCompositionEditorView`'s
/// footer shows live while composing), and — new for this task — its
/// nutrition-source provenance mix (meals-feature-design.md §8.3), so a meal
/// built mostly on hand-entered "Custom" numbers reads differently from one
/// built on Open Food Facts data. Pushed from `MealsView`'s entry list.
struct MealDetailView: View {
    let entry: MealEntry

    private var completeness: NutritionCompleteness {
        MealStore.completeness(for: entry.ingredients)
    }

    private var provenance: NutritionProvenanceMix {
        MealStore.provenanceMix(for: entry.ingredients)
    }

    var body: some View {
        List {
            Section("Ingredients") {
                ForEach(entry.ingredients) { ingredient in
                    ingredientRow(ingredient)
                }
            }

            Section("Nutrition") {
                HStack {
                    MetricView(label: "Calories", value: caloriesText)
                    MetricView(label: "Protein", value: macroText(completeness.total.proteins100g))
                    MetricView(label: "Carbs", value: macroText(completeness.total.carbohydrates100g))
                    MetricView(label: "Fat", value: macroText(completeness.total.fat100g))
                }
                if !completeness.isComplete {
                    Label(
                        "\(completeness.missingCount) of \(completeness.consideredCount) ingredient\(completeness.consideredCount == 1 ? "" : "s") missing nutrition data",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            if provenance.consideredCount > 0 {
                Section("Data Source") {
                    provenanceMixView
                }
            }
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func ingredientRow(_ ingredient: LoggedIngredient) -> some View {
        HStack(spacing: 12) {
            if let url = ingredient.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading) {
                Text(ingredient.productName ?? "Unknown Product")
                    .font(.subheadline)
                Text("\(ingredient.amount.formatted(.number.precision(.fractionLength(0...2)))) \(ingredient.unitLabel)\(ingredient.usesFromPantry ? "" : " · not from pantry")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let kcal = ingredient.nutritionSnapshot?.energyKcal100g {
                Text("\(kcal.formatted(.number.precision(.fractionLength(0...0)))) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    /// "3 of 4 ingredients from Open Food Facts, 1 Custom" plus a small
    /// proportional bar, reusing `ProductDetailCard`'s color convention
    /// (blue = Open Food Facts, orange = Custom) so the badge language is
    /// consistent across the app.
    private var provenanceMixView: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if provenance.openFoodFactsCount > 0 {
                        Color.blue.opacity(0.6)
                            .frame(width: geometry.size.width * fraction(provenance.openFoodFactsCount))
                    }
                    if provenance.customCount > 0 {
                        Color.orange.opacity(0.6)
                            .frame(width: geometry.size.width * fraction(provenance.customCount))
                    }
                    if provenance.unknownCount > 0 {
                        Color.gray.opacity(0.4)
                            .frame(width: geometry.size.width * fraction(provenance.unknownCount))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)

            if provenance.openFoodFactsCount > 0 {
                sourceLegendRow(color: .blue, label: "Open Food Facts", count: provenance.openFoodFactsCount)
            }
            if provenance.customCount > 0 {
                sourceLegendRow(color: .orange, label: "Custom", count: provenance.customCount)
            }
            if provenance.unknownCount > 0 {
                sourceLegendRow(color: .gray, label: "Unknown", count: provenance.unknownCount)
            }
        }
        .padding(.vertical, 4)
    }

    private func sourceLegendRow(color: Color, label: String, count: Int) -> some View {
        HStack {
            Circle().fill(color.opacity(0.6)).frame(width: 8, height: 8)
            Text(label).font(.caption)
            Spacer()
            Text("\(count)").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func fraction(_ count: Int) -> Double {
        guard provenance.consideredCount > 0 else { return 0 }
        return Double(count) / Double(provenance.consideredCount)
    }

    private var caloriesText: String {
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        return completeness.isComplete ? "\(kcal) kcal" : "≥ \(kcal) kcal"
    }

    private func macroText(_ grams: Double?) -> String {
        "\((grams ?? 0).formatted(.number.precision(.fractionLength(0...1))))g"
    }
}
