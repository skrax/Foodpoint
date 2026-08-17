import SwiftUI
import FoodpointKit

/// Meals tab's most-consumed list across all products (MK-6,
/// meals-feature-design.md §9) — ranked by `MealStore.mostConsumed(from:to:)`
/// over the trailing 30 days. `ConsumptionStats` itself only carries a
/// barcode (`MealKit` snapshots no product catalog of its own — §3.2), so
/// this view resolves each barcode's display name/image the same
/// network-free way the composition editor's "from history" source does:
/// `appState.meals.recentlyUsedIngredients()` already gives one
/// already-snapshotted `LoggedIngredient` per barcode.
struct MostConsumedView: View {
    @Environment(AppState.self) private var appState

    private var calendar: Calendar { .current }

    private var rangeStart: Date {
        calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: Date())) ?? Date()
    }

    private var stats: [ConsumptionStats] {
        appState.meals.mostConsumed(from: rangeStart, to: Date(), calendar: calendar)
    }

    /// Most-recent `LoggedIngredient` per barcode, for display fields only —
    /// no network call, matching `recentlyUsedIngredients()`'s own contract.
    private var ingredientByBarcode: [String: LoggedIngredient] {
        Dictionary(
            appState.meals.recentlyUsedIngredients().map { ($0.barcode, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        Group {
            if stats.isEmpty {
                ContentUnavailableView(
                    "No Meals Logged Yet",
                    systemImage: "chart.bar",
                    description: Text("Products you eat show up here, ranked by how often you eat them, over the last 30 days.")
                )
            } else {
                List(stats, id: \.barcode) { stat in
                    row(for: stat)
                }
            }
        }
        .navigationTitle("Most Consumed")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for stat: ConsumptionStats) -> some View {
        let ingredient = ingredientByBarcode[stat.barcode]
        return HStack(spacing: 12) {
            if let url = ingredient?.imageURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading) {
                Text(ingredient?.productName ?? "Unknown Product")
                    .font(.headline)
                if let brand = ingredient?.productBrand {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.timesEaten)×")
                    .font(.subheadline)
                    .bold()
                if let lastEaten = stat.lastEatenDate {
                    Text(lastEaten, format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
