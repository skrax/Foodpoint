import SwiftUI
import FoodpointKit

/// Detail screen for one `MealEntry` (MK-6): its ingredient rows, a nutrition
/// completeness total (§8.2, same signal `MealCompositionEditorView`'s
/// footer shows live while composing), and its nutrition-source provenance
/// mix (meals-feature-design.md §8.3), so a meal built mostly on hand-entered
/// "Custom" numbers reads differently from one built on Open Food Facts data.
/// Pushed from `DayTimelineView`'s entry list.
///
/// Takes `entryID` rather than a plain `MealEntry` snapshot and looks the
/// entry up live from `appState.meals.entries` on every render (`entry`
/// below) — needed since FX-4's "Edit" button (see its own doc comment)
/// mutates this same entry's ingredients in place via
/// `AppState.updateMealIngredients`, and a value captured once at push time
/// would go stale the moment that save happens, still showing the
/// pre-edit ingredient list. Shows a "Meal Not Found" placeholder for the
/// (currently unreachable before FX-5, but safe to handle) case of the
/// entry having been removed out from under this screen — which FX-5's own
/// "Delete" button now makes reachable in the instant between deletion and
/// `dismiss()` popping this screen.
///
/// **FX-5 addition**: a toolbar "Delete" button alongside "Edit",
/// `requestDelete()`-shaped identically to `DayTimelineView`'s row-level
/// affordance (see that view's doc comment) — a `.planned` entry deletes
/// immediately, an `.eaten` entry confirms first since its deletion
/// restores real pantry stock. Either way a successful delete calls
/// `dismiss()` to pop back to the timeline, since `entry` (and thus this
/// whole screen's content) no longer exists once its `MealEntry` is gone.
struct MealDetailView: View {
    let entryID: MealEntry.ID

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Presents `MealCompositionEditorView` pre-populated with this entry's
    /// current ingredients (FX-4) — `true` only while an edit sheet is on
    /// screen; the sheet reads `entry` fresh each time it's opened, so it
    /// always starts from whatever's currently saved, not a stale copy.
    @State private var isShowingEditor = false

    /// `true` while the "Delete Meal?" confirmation alert is on screen
    /// (FX-5) — only shown for an `.eaten` entry, whose deletion has a real
    /// pantry side effect; a `.planned` entry's "Delete" button skips this
    /// and deletes immediately (see `requestDelete(_:)`).
    @State private var isShowingDeleteConfirmation = false

    private var entry: MealEntry? {
        appState.meals.entries.first(where: { $0.id == entryID })
    }

    private func completeness(for entry: MealEntry) -> NutritionCompleteness {
        MealStore.completeness(for: entry.ingredients)
    }

    private func provenance(for entry: MealEntry) -> NutritionProvenanceMix {
        MealStore.provenanceMix(for: entry.ingredients)
    }

    var body: some View {
        Group {
            if let entry {
                detail(for: entry)
            } else {
                ContentUnavailableView("Meal Not Found", systemImage: "questionmark.circle")
            }
        }
    }

    private func detail(for entry: MealEntry) -> some View {
        let completeness = completeness(for: entry)
        let provenance = provenance(for: entry)

        return List {
            Section("Ingredients") {
                ForEach(entry.ingredients) { ingredient in
                    ingredientRow(ingredient)
                }
            }

            Section("Nutrition") {
                HStack {
                    MetricView(label: "Calories", value: caloriesText(for: completeness))
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
                    provenanceMixView(provenance)
                }
            }
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    requestDelete(entry)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            MealCompositionEditorView(initialIngredients: entry.ingredients, title: "Edit Meal") { newIngredients in
                guard !newIngredients.isEmpty else { return }
                appState.updateMealIngredients(entry.id, ingredients: newIngredients)
            }
        }
        .alert("Delete Meal?", isPresented: $isShowingDeleteConfirmation) {
            Button("Delete", role: .destructive) { performDelete(entry) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(entry.name)\" will be removed and its pantry stock restored.")
        }
    }

    /// Deletes `entry` outright (FX-5) — identical `requestDelete`-shaped
    /// judgment call as `DayTimelineView`'s row affordance: a `.planned`
    /// entry has no pantry side effect, so it deletes immediately;
    /// an `.eaten` entry's deletion restores real pantry stock, so this
    /// shows the confirmation alert first instead.
    private func requestDelete(_ entry: MealEntry) {
        if entry.status == .eaten {
            isShowingDeleteConfirmation = true
        } else {
            performDelete(entry)
        }
    }

    /// Actually deletes `entry` via `appState.deleteMeal(_:)` and pops this
    /// screen — called either immediately (`.planned`) or after the
    /// confirmation alert's "Delete" button (`.eaten`).
    private func performDelete(_ entry: MealEntry) {
        appState.deleteMeal(entry.id)
        dismiss()
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
    private func provenanceMixView(_ provenance: NutritionProvenanceMix) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    if provenance.openFoodFactsCount > 0 {
                        Color.blue.opacity(0.6)
                            .frame(width: geometry.size.width * fraction(provenance.openFoodFactsCount, of: provenance))
                    }
                    if provenance.customCount > 0 {
                        Color.orange.opacity(0.6)
                            .frame(width: geometry.size.width * fraction(provenance.customCount, of: provenance))
                    }
                    if provenance.unknownCount > 0 {
                        Color.gray.opacity(0.4)
                            .frame(width: geometry.size.width * fraction(provenance.unknownCount, of: provenance))
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

    private func fraction(_ count: Int, of provenance: NutritionProvenanceMix) -> Double {
        guard provenance.consideredCount > 0 else { return 0 }
        return Double(count) / Double(provenance.consideredCount)
    }

    private func caloriesText(for completeness: NutritionCompleteness) -> String {
        let kcal = (completeness.total.energyKcal100g ?? 0).formatted(.number.precision(.fractionLength(0...0)))
        return completeness.isComplete ? "\(kcal) kcal" : "≥ \(kcal) kcal"
    }

    private func macroText(_ grams: Double?) -> String {
        "\((grams ?? 0).formatted(.number.precision(.fractionLength(0...1))))g"
    }
}
