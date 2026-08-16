import SwiftUI

struct AllItemsProductDetailView: View {
    let barcode: String
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private struct LocationEntry: Identifiable {
        let id: Location.ID
        let name: String
        let quantity: Double
    }

    private var product: FoodProduct? {
        appState.locations.lazy
            .compactMap { $0.items.first { $0.id == barcode }?.product }
            .first
    }

    private var entries: [LocationEntry] {
        appState.locations.compactMap { location in
            guard let item = location.items.first(where: { $0.id == barcode }) else { return nil }
            return LocationEntry(id: location.id, name: location.name, quantity: item.quantity)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let product {
                    ProductDetailCard(product: product)
                }

                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entries.count > 1 ? entry.name : "Quantity")
                                .font(.headline)
                            Spacer()
                            Stepper(
                                value: Binding(
                                    get: { entry.quantity },
                                    set: { appState.setQuantity($0, forItemID: barcode, inLocationWithID: entry.id) }
                                ),
                                in: 0...99,
                                step: 0.5
                            ) {
                                Text(entry.quantity.formatted(.number.precision(.fractionLength(0...2))))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        if entry.id != entries.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .navigationTitle(product?.productName ?? "Product")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: entries.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }
}
