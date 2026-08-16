import SwiftUI
import FoodpointKit

/// "Items" tab: the flat, alphabetically sorted list of every saved product,
/// tapping through to `ItemDetailView` for quantity editing and nutrition.
struct ItemsView: View {
    @Environment(AppState.self) private var appState

    private var sortedItems: [FoodItem] {
        appState.items.sorted { ($0.product.name ?? "") < ($1.product.name ?? "") }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedItems.isEmpty {
                    ContentUnavailableView(
                        "No Products",
                        systemImage: "shippingbox",
                        description: Text("Products you scan appear here.")
                    )
                } else {
                    List(sortedItems) { item in
                        row(for: item)
                    }
                }
            }
            .navigationTitle("Items")
        }
    }

    private func row(for item: FoodItem) -> some View {
        NavigationLink {
            ItemDetailView(itemID: item.id)
        } label: {
            ProductRow(product: item.product, quantity: item.quantity, unitLabel: item.unit.label)
        }
    }
}
