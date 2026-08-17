import SwiftUI
import FoodpointKit

/// "From the pantry" ingredient source (meals-feature-design.md §6.1 #1) —
/// lists `appState.pantry.items` with their remaining quantities so the
/// user can see what they actually have before picking. This is the one
/// acquisition source `MealKit` can't provide on its own (it has zero
/// dependency on `PantryKit`), so it's composed here, at the app layer,
/// which is the only place that can see both `pantry` and `meals` at once —
/// picking a row hands `MealCompositionEditorView` a resolved `Product` +
/// `barcode` + the pantry's own already-configured `ProductUnit` for it, so
/// there's no unit setup to ask about for this source (unlike scan/search).
struct MealIngredientPantryPickerView: View {
    var onSelect: (FoodItem) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var sortedItems: [FoodItem] {
        appState.pantry.items.sorted { ($0.product.name ?? "") < ($1.product.name ?? "") }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedItems.isEmpty {
                    ContentUnavailableView(
                        "Pantry Is Empty",
                        systemImage: "shippingbox",
                        description: Text("Items you've saved to your pantry will show up here.")
                    )
                } else {
                    List(sortedItems) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            ProductRow(product: item.product, quantity: item.quantity, unitLabel: item.unit.label)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("From Pantry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
