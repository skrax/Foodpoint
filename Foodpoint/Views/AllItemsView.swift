import SwiftUI

struct AllItemsView: View {
    @Environment(AppState.self) private var appState

    private var aggregatedItems: [LocationItem] {
        var totals: [String: LocationItem] = [:]
        for location in appState.locations {
            for item in location.items {
                if let existing = totals[item.id] {
                    totals[item.id] = LocationItem(id: item.id, product: existing.product, quantity: existing.quantity + item.quantity)
                } else {
                    totals[item.id] = item
                }
            }
        }
        return totals.values.sorted { ($0.product.productName ?? "") < ($1.product.productName ?? "") }
    }

    var body: some View {
        NavigationStack {
            Group {
                if aggregatedItems.isEmpty {
                    ContentUnavailableView(
                        "No Products",
                        systemImage: "shippingbox",
                        description: Text("Products you add to a location appear here.")
                    )
                } else {
                    List(aggregatedItems) { item in
                        row(for: item)
                    }
                }
            }
            .navigationTitle("All Items")
        }
    }

    private func row(for item: LocationItem) -> some View {
        NavigationLink {
            ScrollView {
                ProductDetailCard(product: item.product)
            }
            .navigationTitle(item.product.productName ?? "Product")
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.product.productName ?? "Unknown Product")
                        .font(.headline)
                    if let brands = item.product.brands {
                        Text(brands)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("×\(item.quantity)")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
