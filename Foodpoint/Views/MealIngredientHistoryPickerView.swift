import SwiftUI
import FoodpointKit

/// "From history" ingredient source (meals-feature-design.md §6.1 #2) —
/// lists `appState.meals.recentlyUsedIngredients()`, one row per barcode
/// this store has ever logged before, most-recently-used first. Purely a
/// `MealKit` concern: no network call, no dependency on `PantryKit` — it's
/// just reading already-snapshotted `LoggedIngredient` fields, including
/// products no longer in the pantry at all.
struct MealIngredientHistoryPickerView: View {
    var onSelect: (LoggedIngredient) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            let history = appState.meals.recentlyUsedIngredients()
            Group {
                if history.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Ingredients you've logged before will show up here for quick reuse.")
                    )
                } else {
                    List(history) { ingredient in
                        Button {
                            onSelect(ingredient)
                            dismiss()
                        } label: {
                            row(for: ingredient)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("From History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(for ingredient: LoggedIngredient) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(ingredient.productName ?? "Unknown Product")
                    .font(.headline)
                if let brand = ingredient.productBrand {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("last: \(ingredient.amount.formatted(.number.precision(.fractionLength(0...2)))) \(ingredient.unitLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
